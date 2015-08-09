let AppAwareMixin,
    Route,
    Router,
    Routes,
    ref,
    slice = [].slice;

require('object.assign').shim();

const React = require('react');

exports.AppAwareMixin = AppAwareMixin = {
  contextTypes: {
    app: React.PropTypes.object
  }
};

const URI = require('URIjs');

const _ = require('underscore');

const Bacon = require('bacon.model');

({ Route, Routes } = Router = require('react-router'));

const Notebook = require('./notebook');

const Builtins = require('./builtins');

const Settings = require('./settings');

const GitHub = require('./github');

const Context = require('./context');

const ContextComponents = require('./contextComponents');

const Builder = require('./builder');

const Documentation = require('./documentation');

const Modules = require('./modules');

const Components = require('./components');

const Server = require('./server');

const SettingsComponent = require('./settingsComponent');

Settings['default']('app', 'intro_command', 'help \'introduction\'');

let initializationPromise = null;


const InitializationFailureModal = React.createClass({
  render() {
    const footer = React.DOM.button({
      onClick: this.props.dismiss
    }, 'OK');

    return exports.ModalComponent({
      title: 'Lead Failed to Start Properly',
      footer: footer
    }, React.DOM.p({}, 'An error occurred while starting lead. More details may be available in the browser\'s console. Some features might not be available. Try reloading this page.'), React.DOM.p({
      style: {
        marginTop: '1em'
      }
    }, 'Message: ', this.props.error));
  }
});


exports.init_app = function (target, options) {
  let query, ref1;
  if (options == null) {
    options = {};
  }
  try {
    Settings.user_settings.set((ref1 = JSON.parse(localStorage.getItem('lead_user_settings'))) != null ? ref1 : {});
  } catch (_error) {
    const e = _error;

    console.error('failed loading user settings', e);
  }
  const modules = {
    http: require('./http'),
    dsl: require('./dsl'),
    compat: require('./compat'),
    graphing: require('./graphing'),
    input: require('./input'),
    opentsdb: require('./opentsdb'),
    settings: Settings,
    context: Context,
    builtins: Builtins,
    notebook: Notebook,
    server: Server,
    github: GitHub
  };

  _.extend(modules, options.modules);
  const imports = ['builtins.*', 'server.*', 'github.*', 'graphing.*', 'compat.*', 'opentsdb.tsd'];

  imports.push.apply(imports, Settings.get('app', 'imports') || []);
  window.addEventListener('storage', e => {
    let ref2;
    if (e.key === 'lead_user_settings') {
      console.log('updating user settings');
      try {
        return Settings.user_settings.set((ref2 = JSON.parse(e.newValue)) != null ? ref2 : {});
      } catch (_error) {
        e = _error;
        return console.error('failed updating user settings', e);
      }
    }
  });
  Settings.user_settings.changes.onValue(function () {
    return localStorage.setItem('lead_user_settings', JSON.stringify(Settings.user_settings.get()));
  });
  const publicUrl = Settings.get('app', 'publicUrl');

  if (publicUrl != null) {
    __webpack_public_path__ = publicUrl;
  }
  const extraRoutes = options.extraRoutes || [];
  const bodyWrapper = options.bodyWrapper;

  if (location.search !== '') {
    const uri = URI(location.href);

    if (uri.hash() === '') {
      query = encodeURIComponent(uri.query());
    } else {
      query = uri.query();
    }
    uri.hash(uri.hash() + '?' + query);
    uri.query(null);
    window.history.replaceState(null, document.title, uri.toString());
  }



  const app = {
    imports: imports,
    modules: modules
  };

  initializationPromise = Modules.init_modules(modules);
  initializationPromise.fail(function (e) {
    console.error('Failure initializing modules', e);
    return exports.pushModal({
      handler: InitializationFailureModal,
      props: {
        error: e
      }
    });
  });
  return React.renderComponent(routesComponent, target);
};

const encodeNotebookValue = function (value) {
  return btoa(unescape(encodeURIComponent(value)));
};

exports.raw_cell_url = function (ctx, value) {
  const encoded = encodeNotebookValue(value);

  return URI(ctx.app.appComponent.makeHref('raw_notebook', {
    splat: encoded
  })).absoluteTo(location.href).toString();
};

exports.SingleCoffeeScriptCellNotebookComponent = SingleCoffeeScriptCellNotebookComponent;

window.lead = {
  settings: Settings,
  init_app: exports.init_app,
  Router: Router,
  React: React
};

window.React = React;
