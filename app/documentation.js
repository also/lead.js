import React from 'react';
import _ from 'underscore';

import LeadMarkdownComponent from './markdown/LeadMarkdownComponent';
import * as Context from './context';
import {ContextAwareMixin} from './contextComponents';

const docs = {};

function getParent(key) {
  let parent = docs;
  key.forEach((segment) => {
    parent = parent[segment] != null ? parent[segment] : parent[segment] = {};
  });
  return parent;
}

function normalizeKey(key) {
  if (_.isArray(key)) {
    return key;
  } else {
    return key.split('.');
  }
}

export function getDocumentation(key) {
  return getParent(normalizeKey(key))._lead_doc;
}

function resolveKey(ctx, o) {
  const resolvers = Context.collect_extension_points(ctx, 'resolveDocumentationKey');
  let result = null;
  _.find(resolvers, (resolver) => {
    const key = resolver(ctx, o);
    if (key && getDocumentation(key)) {
      result = key;
      return true;
    }
  });

  return result;
}

export function keyToString(key) {
  if (_.isArray(key)) {
    return key.join('.');
  } else {
    return key;
  }
}

export function navigate(ctx, key) {
  key = keyToString(key);
  if (ctx.docsNavigate != null) {
    return ctx.docsNavigate(key);
  } else {
    return ctx.run("help '" + key + "'");
  }
}

export function register(key, doc) {
  key = normalizeKey(key);
  doc = _.extend({
    key: key
  }, doc);

  getParent(key)._lead_doc = doc;
}

export function keys(key) {
  return _.filter(_.map(getParent(normalizeKey(key)), (v, k) => {
    if (v._lead_doc != null) {
      return k;
    } else {
      return null;
    }
  }), _.identity);
}

export function summary(ctx, doc) {
  if (_.isFunction(doc.summary)) {
    return doc.summary(ctx, doc);
  } else if (_.isString(doc.summary)) {
    return <p>{doc.summary}</p>;
  } else {
    return doc.summary;
  }
}

export function complete(ctx, doc) {
  if (_.isFunction(doc.complete)) {
    return doc.complete(ctx, doc);
  } else if (_.isString(doc.complete)) {
    return <LeadMarkdownComponent value={doc.complete}/>;
  } else if (doc.index) {
    return index(ctx, doc.key);
  } else {
    return doc.complete;
  }
}

export function index(ctx, key) {
  key = normalizeKey(key);

  const entries = keys(key).map((k) => {
    const entryKey = key.concat(k);
    return {
      name: k,
      key: entryKey,
      doc: getDocumentation(entryKey)
    };
  });

  return <DocumentationIndexComponent {...{ctx, entries}}/>;
}

export function getKey(ctx, o) {
  if (o == null) {
    return ['main'];
  }

  let key;
  if (_.isString(o)) {
    const doc = getDocumentation(o);
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

  if (getDocumentation(key)) {
    return key;
  } else {
    return null;
  }
}

export function loadFile(name) {
  if (process.browser) {
    return () => {
      const {images, content} = require(`../lib/markdown-loader.coffee!../docs/${name}.md`);
      return <LeadMarkdownComponent value={content} image_urls={images}/>;
    };
  }
}

export function registerLeadMarkdown(key, {images, content}) {
  return register(key, {
    complete: <LeadMarkdownComponent value={content} image_urls={images}/>
  });
}

function registerFile(name, key) {
  return register(key != null ? key : name, {
    complete: loadFile(name)
  });
}

export {normalizeKey as keyToPath};

export const DocumentationLinkComponent = React.createClass({
  displayName: 'DocumentationLinkComponent',

  mixins: [ContextAwareMixin],

  showHelp() {
    return navigate(this.state.ctx, this.props.key);
  },

  render() {
    return (
      <span className='run-link' onClick={this.showHelp}>
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

registerFile('quickstart');
registerFile('style');
registerFile('main');
registerFile('introduction');

register('imported', {
  complete(ctx, doc) {
    const fnDocs = Object.keys(ctx.imported).map((name) => {
      const fn = ctx.imported[name];
      if (fn && fn.module_name != null && fn.name != null) {
        const key = [fn.module_name, fn.name];
        doc = getDocumentation(key);
        if (doc != null) {
          return {name, doc, key};
        }
      }
    });

    const entries = _.sortBy(_.filter(fnDocs, _.identity), 'name');

    return <DocumentationIndexComponent {...{entries, ctx}}/>;
  }
});

register('module_list', {
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
