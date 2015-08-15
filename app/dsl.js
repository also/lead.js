/* eslint-disable new-cap */

import _ from 'underscore';

import * as Context from './context';
import * as Components from './components';


export const type = function () {};

function createType(n, parent, f) {
  const t = function (...args) {
    this.type = n;
    return f.apply(this, args);
  };

  t.prototype = new parent();
  return type[n] = t;
}

// binding for converting objects to param() calls
let toStringContext = null;

// Create the types:
//  f: function invocation
//  q: raw string
//  b: boolean
//  n: number
//  s: string
//  i: identifier
//  o: jsonable object

createType('f', type, function (name, args) {
  this.name = name;
  this.args = args;
});

type.f.prototype.to_target_string = function () {
  return `${this.name}(${this.args.map((a) => a.to_target_string()).join(',')})`;
};

type.f.prototype.to_js_string = function () {
  return `${this.name}(${this.args.map((a) => a.to_js_string()).join(',')})`;
};

createType('q', type, function (...values) {
  this.values = values;
});

type.q.prototype.to_target_string = function () {
  return this.values.join(',');
};

type.q.prototype.to_js_string = function () {
  return `q(${this.values.map(JSON.stringify).join(', ')})`;
};

createType('p', type, function (value) {
  this.value = value;
});

// numbers, strings, jsonable objects, and booleans use json serialization
type.p.prototype.to_js_string = type.p.prototype.to_target_string = function () {
  return JSON.stringify(this.value);
};

for (const n of 'nsbo') {
  createType(n, type.p, function (value) {
    this.value = value;
  });
}

type.TRUE = new type.b(true);

type.FALSE = new type.b(false);

// Graphite doesn't support escaped quotes in strings, so avoid including any if possible.
type.s.prototype.to_target_string = function () {
  let quoteChar;
  const s = this.value;

  if (s.indexOf('"') >= 0 || s.indexOf('\'') < 0) {
    quoteChar = '\'';
  } else {
    quoteChar = '"';
  }
  return quoteChar + s.replace(quoteChar, '\\' + quoteChar) + quoteChar;
};

createType('i', type, function (value) {
  this.value = value;
});

type.i.prototype.to_target_string = type.s.prototype.to_target_string;

type.i.prototype.to_js_string = function () {
  return this.value;
};

type.i.prototype.toJSON = function () {
  return {
    type: this.type,
    name: this.fn_name
  };
};

Object.assign(type.i.prototype, _.pick(Function.prototype, ['length', 'name', 'bind', 'toString', 'call', 'apply']));

type.o.prototype.to_target_string = function () {
  const objects = toStringContext.objects != null ? toStringContext.objects : toStringContext.objects = [];
  const i = objects.length;

  objects.push(this.value);
  return 'param(\'objects\',' + i + ')';
};

function processArg(arg) {
  if (arg instanceof type) {
    return arg;
  }
  if (typeof arg === 'number') {
    return new type.n(arg);
  }
  if (_.isString(arg)) {
    return new type.s(arg);
  }
  if (_.isBoolean(arg)) {
    return new type.b(arg);
  } else if (_.isArray(arg) || _.isObject(arg)) {
    return new type.o(arg);
  }
  throw new TypeError(`illegal argument ${arg}`);
}

function dsl_fn(name) {
  const result = function (...args) {
    return new type.f(name, args.map(processArg));
  };

  result.type = 'i';
  result.fn_name = name;
  result.value = name;
  result.__proto__ = new type.i();
  return result;
}

export function define_functions(ns, names) {
  names.forEach((name) => ns[name] = dsl_fn(name));
  return ns;
}

export function to_string(node) {
  if (!(node instanceof type)) {
    throw new TypeError(`${node} is not a dsl node`);
  }
  return node.to_target_string();
}

export function to_target_string(node, context) {
  if (_.isString(node)) {
    return node;
  } else {
    try {
      toStringContext = context;
      return to_string(node);
    } finally {
      toStringContext = null;
    }
  }
}

export function to_js_string(node) {
  return node.to_js_string();
}

export function is_dsl_node(x) {
  return x instanceof type;
}

// TODO rename
export function context_result_handler(ctx, object) {
  if (is_dsl_node(object)) {
    const leadString = to_string(object);

    if (_.isFunction(object)) {
      Context.add_component(ctx, (
        <div>
          {leadString} is a server function
          <Components.ExampleComponent value={`help 'server.functions.${object.fn_name}'`} run={true}/>
        </div>
      ));
    } else {
      Context.add_component(ctx, <Components.ExampleComponent value={`graph ${object.to_js_string()}`} run={true}/>);
    }
    return true;
  }
}
