import Q from 'q';
import _ from 'underscore';
import Bacon from 'bacon.model';
import React from 'react/addons';

import * as Builtins from './builtins';
import {addComponent} from './componentList';
import {IGNORE, collect_extension_points} from './context';

// statement result handlers. return truthy if handled.
function ignored(ctx, object) {
  return object === IGNORE;
}

function handleCmd(ctx, object) {
  if (object && object._lead_context_fn) {
    const op = object._lead_context_fn;
    if (op.cmd_fn != null) {
      op.cmd_fn.call(null, ctx);
      return true;
    } else {
      addComponent(ctx,
        <div>
          Did you forget to call a function? {object._lead_context_name} must be called with arguments.
          {Builtins.help_component(ctx, object)}
        </div>
      );
      return true;
    }
  }
}

function handleModule(ctx, object) {
  if (object && object._lead_context_name) {
    addComponent(ctx,
      <div>{object._lead_context_name}
        is a module.
        {Builtins.help_component(ctx, object)}
      </div>
    );
    return true;
  }
}

function handleUsingExtension(ctx, object) {
  const handlers = collect_extension_points(ctx, 'context_result_handler');
  return _.find(handlers, (handler) => {
    return handler(ctx, object);
  });
}

function handlePromise(ctx, object) {
  if (Q.isPromise(object)) {
    addComponent(ctx, <Builtins.PromiseComponent promise={object}/>);
    return true;
  }
}

function handleObservable(ctx, object) {
  if (object instanceof Bacon.Observable) {
    addComponent(ctx, <Builtins.ObservableComponent observable={object}/>);
    return true;
  }
}

function handleComponent(ctx, object) {
  if (React.isValidElement(object)) {
    addComponent(ctx, object);
    return true;
  }
}

function handleAnyObject(ctx, object) {
  addComponent(ctx, <Builtins.ObjectBrowserComponent object={object}/>);
  return true;
}

// TODO make this configurable
const resultHandlers = [
  ignored,
  handleCmd,
  handleModule,
  handleUsingExtension,
  handlePromise,
  handleObservable,
  handleComponent,
  handleAnyObject
];

export default function (ctx, object) {
  for (const handler of resultHandlers) {
    if (handler(ctx, object)) {
      return;
    }
  }
}
