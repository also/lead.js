import React from 'react';
import _ from 'underscore';

import Markdown from './markdown';
import Context from './context';
import {ContextAwareMixin} from './contextComponents';

const docs = {};

const getParent = function(key) {
  let parent = docs;
  key.forEach((segment) => {
    parent = parent[segment] != null ? parent[segment] : parent[segment] = {};
  });
  return parent;
};

const normalizeKey = function(key) {
  if (_.isArray(key)) {
    return key;
  } else {
    return key.split('.');
  }
};

export const get_documentation = function(key) {
  return getParent(normalizeKey(key))._lead_doc;
};

const resolveKey = function(ctx, o) {
  const resolvers = Context.collect_extension_points(ctx, 'resolve_documentation_key');
  let result = null;
  _.find(resolvers, (resolver) => {
    const key = resolver(ctx, o);
    if (key && get_documentation(key)) {
      result = key;
      return true;
    }
  });

  return result;
};

export const key_to_string = function(key) {
  if (_.isArray(key)) {
    return key.join('.');
  } else {
    return key;
  }
};

export const navigate = function(ctx, key) {
  key = key_to_string(key);
  if (ctx.docs_navigate != null) {
    return ctx.docs_navigate(key);
  } else {
    return ctx.run("help '" + key + "'");
  }
};

export const register_documentation = function(key, doc) {
  key = normalizeKey(key);
  doc = _.extend({
    key: key
  }, doc);

  getParent(key)._lead_doc = doc;
};

export const keys = function(key) {
  return _.filter(_.map(getParent(normalizeKey(key)), (v, k) => {
    if (v._lead_doc != null) {
      return k;
    } else {
      return null;
    }
  }), _.identity);
};

export const summary = function(ctx, doc) {
  if (_.isFunction(doc.summary)) {
    return doc.summary(ctx, doc);
  } else if (_.isString(doc.summary)) {
    return React.DOM.p({}, doc.summary);
  } else {
    return doc.summary;
  }
};

export const complete = function(ctx, doc) {
  if (_.isFunction(doc.complete)) {
    return doc.complete(ctx, doc);
  } else if (_.isString(doc.complete)) {
    return Markdown.LeadMarkdownComponent({
      value: doc.complete
    });
  } else if (doc.index) {
    return index(ctx, doc.key);
  } else {
    return doc.complete;
  }
};

export const index = function(ctx, key) {
  key = normalizeKey(key);

  const entries = keys(key).map((k) => {
    const entryKey = key.concat(k);
    return {
      name: k,
      key: entryKey,
      doc: get_documentation(entryKey)
    };
  });

  return <DocumentationIndexComponent {...{ctx, entries}}/>;
};

export const get_key = function(ctx, o) {
  if (o == null) {
    return ['main'];
  }

  let key;
  if (_.isString(o)) {
    const doc = get_documentation(o);
    if (doc != null) {
      return o;
    } else {
      const scoped = Context.find_in_scope(ctx, o);
      if (scoped) {
        key = resolveKey(ctx, scoped);
      } else {
        key = resolveKey(ctx, o);
      }
    }
  } else {
    key = resolveKey(ctx, o);
  }

  if (!key) {
    return null;
  }

  if (get_documentation(key)) {
    return key;
  } else {
    return null;
  }
};

export const load_file = function(name) {
  if (process.browser) {
    return function() {
      const {images, content} = require("../lib/markdown-loader.coffee!../docs/" + name + ".md");
      return Markdown.LeadMarkdownComponent({
        value: content,
        image_urls: images
      });
    };
  }
};

export const registerLeadMarkdown = function(key, {images, content}) {
  return register_documentation(key, {
    complete: Markdown.LeadMarkdownComponent({
      value: content,
      image_urls: images
    })
  });
};

export const register_file = function(name, key) {
  return register_documentation(key != null ? key : name, {
    complete: load_file(name)
  });
};

export {normalizeKey as key_to_path};

export const DocumentationLinkComponent = React.createClass({
  displayName: 'DocumentationLinkComponent',

  mixins: [ContextAwareMixin],

  showHelp() {
    return navigate(this.state.ctx, this.props.key);
  },

  render() {
    return (
      <span className="run-link" onClick={this.showHelp}>
        {this.props.children}
      </span>
    );
  }
});

export const DocumentationIndexComponent = React.createClass({
  displayName: 'DocumentationIndexComponent',

  render() {
    return <table>
      {this.props.entries.map((e) => {
        const key = e.key != null ? e.key : e.name;

        return (
          <tr key={key}>
            <td><DocumentationLinkComponent key={key}><code>{e.name}</code></DocumentationLinkComponent></td>
            <td>{summary(this.props.ctx, e.doc)}</td>
          </tr>
        );
      })}
    </table>;
  }
});

export const DocumentationItemComponent = React.createClass({
  render() {
    return (
      <div>
        {complete(this.props.ctx, this.props.doc) || summary(this.props.ctx, this.props.doc)}
      </div>
    );
  }
});

register_file('quickstart');
register_file('style');
register_file('main');
register_file('introduction');

register_documentation('imported', {
  complete(ctx, doc) {
    const fnDocs = Object.keys(ctx.imported).map((name) => {
      const fn = ctx.imported[name];
      if (fn && fn.module_name != null && fn.name != null) {
        const key = [fn.module_name, fn.name];
        doc = get_documentation(key);
        if (doc != null) {
          return {name, doc, key};
        }
      }
    });

    const entries = _.sortBy(_.filter(fnDocs, _.identity), 'name');

    return <DocumentationIndexComponent {...{entries, ctx}}/>;
  }
});

register_documentation('module_list', {
  complete(ctx) {
    const entries = _.sortBy(_.map(_.keys(ctx.modules), (name) => {
      return {
        name: name,
        doc: {
          summary: ''
        }
      };
    }), 'name');

    return <DocumentationIndexComponent {...{entries, ctx}}/>;
  }
});
