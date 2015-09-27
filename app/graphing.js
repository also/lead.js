import _ from 'underscore';
import moment from 'moment';
import Q from 'q';
import Bacon from 'bacon.model';
import React from 'react/addons';
import {connect} from 'react-redux';

import * as modules from './modules';
import * as Documentation from './documentation';
import * as Server from './server';
import WrappedGraphComponent from './graph/GraphComponent';
import * as Context from './context';
import * as Builtins from './builtins';
import {pushModal} from './actions';
import * as Modal from './modal';


const ExportModal = React.createClass({
  render() {
    const {url} = this.props;

    const footer = <button onClick={this.props.dismiss}>OK</button>;

    return (
      <Modal.ModalComponent footer={footer}>
        <img src={url} style={{border: '1px solid #aaa'}}/>
      </Modal.ModalComponent>
    );
  }
});

function brushParams(params, brush) {
  return brush.filter(({brushing}) => !brushing)
  .map(({extent}) => {
    if (extent != null) {
      return {
        start: moment(extent[0]).unix(),
        end: moment(extent[1]).unix()
      };
    } else {
      return {
        start: params.start,
        end: params.end
      };
    }
  });
}

function wrapModel(model) {
  if (model != null) {
    if (model.get() instanceof Bacon.Observable) {
      return model;
    } else {
      return new Bacon.Model(model);
    }
  }
}

/** wrap params that are could be models so they aren't interpreted as streams by combineTemplate */
function wrapParams(params) {
  if (params.cursor != null || params.brush != null) {
    params = Object.assign({}, params, {
      cursor: wrapModel(params.cursor),
      brush: wrapModel(params.brush)
    });
  }
  return params;
}

function serverDataSource(ctx, serverParams) {
  return new Server.LeadDataSource((params) => {
    return Server.getData(ctx, Object.assign({}, serverParams, params));
  });
}

function paramModifier(newParams) {
  return (currentParams) => {
    const result = Object.assign({}, currentParams, newParams);

    // Bacon checks for quality with ===, so don't change the value if possible
    if (_.isEqual(currentParams, result)) {
      return currentParams;
    } else {
      return result;
    }
  };
}

modules.export(exports, 'graphing', ({componentFn, doc, cmd, fn}) => {
  doc('shareCursor', 'Use the same cursor on multiple graphs',
  `
  # Usage

  ## \`shareCursor()\`

  Sets the \`cursor\` option to a new cursor. This cursor will be used by all subsequent calls to [\`graph\`](help:graphing.graph).

  ## \`shareCursor(false)\`

  Unsets the \`cursor\` option.

  ## \`shareCursor(cursor)\`

  Sets the value of the \`cursor\` option to the specified cursor.
  `);
  cmd('shareCursor', (ctx, share) => {
    if (share == null) {
      share = true;
    }
    const options = ctx.options();

    if (share === false) {
      return delete options.cursor;
    } else if (share instanceof Bacon.Observable) {
      return options.cursor = share;
    } else {
      return options.cursor = new Bacon.Model();
    }
  });

  doc('shareBrush', 'Use the same brush on multiple graphs',
  `
  # Usage

  ## \`shareBrush()\`

  Sets the \`brush\` option to a new brush. This brush will be used by all subsequent calls to [\`graph\`](help:graphing.graph).

  ## \`shareBrush(false)\`

  Unsets the \`brush\` option.

  ## \`shareBrush(brush)\`

  Sets the value of the \`brush\` option to the specified brush.
  `);
  cmd('shareBrush', (ctx, share) => {
    if (share == null) {
      share = true;
    }
    const options = ctx.options();

    if (share === false) {
      return delete options.brush;
    } else if (share instanceof Bacon.Observable) {
      return options.brush = share;
    } else {
      return options.brush = new Bacon.Model();
    }
  });

  fn('brushParams', (ctx, brush) => {
    return Context.value(brushParams(brush != null ? brush : ctx.options().brush));
  });

  doc('graph', 'Loads and graphs time-series data', Documentation.loadFile('graphing.graph'));
  componentFn('graph', (ctx, ...args) => {
    const model = createModel(ctx, ...args);

    return <GraphComponent model={model}/>;
  });
});

export function createModel(ctx, ...args) {
  let data, params, promise, source;

  if (Q.isPromise(args[0])) {
    promise = args[0];
    params = Object.assign({}, ctx.options(), args[1]);
  } else if (_.isArray(args[0]) && args[0][0] && args[0][0].datapoints) {
    data = Bacon.constant(args[0]);
    params = Object.assign({}, ctx.options(), args[1]);
  } else if (args[0] instanceof Bacon.Observable) {
    data = args[0];
    params = Object.assign({}, ctx.options(), args[1]);
  } else {
    if (args[0] instanceof Server.LeadDataSource) {
      source = args[0];
      params = Object.assign({}, ctx.options(), args[1]);
    } else {
      const all_params = Server.args_to_params(ctx, {
        args: args,
        defaultOptions: ctx.options()
      });

      params = all_params.client;
      source = serverDataSource(ctx, all_params.server);
    }

    const paramModifiers = [];

    if (params.bindToBrush === true) {
      if (params.brush == null) {
        params.brush = new Bacon.Model();
      }
      paramModifiers.push(brushParams(params, params.brush).changes());
    } else if (params.bindToBrush instanceof Bacon.Observable) {
      if (params.brush == null) {
        params.brush = params.bindToBrush;
      }
      paramModifiers.push(brushParams(params, params.bindToBrush).changes());
    }

    if (params.refreshInterval != null) {
      paramModifiers.push(Bacon.interval(params.refreshInterval * 1000, {}).map(() => {
        return {refreshTime: +new Date()};
      }));
    }

    if (paramModifiers.length > 0) {
      // create a single stream of all param modifiers
      const paramModifierStream = Bacon.mergeAll(paramModifiers).map(paramModifier);
      const paramsProp = paramModifierStream.scan(params, (v, f) => {
        return f(v);
      });

      data = paramsProp.flatMapLatest((params) => {
        return Bacon.fromPromise(source.load(params));
      });
    } else {
      promise = source.load(params);
    }
  }

  if (promise) {
    data = Bacon.fromPromise(promise);
  }

  // create a stream where every event will be {data} or {error}
  const dataOrError = data.withHandler(function (e) {
    if (e.isError()) {
      this.push(new Bacon.Next({
        error: e.error
      }));
    } else {
      this.push(e.fmap((data) => ({data})));
    }
  });

  return Bacon.combineTemplate({
    data: dataOrError.map(({data}) => data),
    error: dataOrError.map(({error}) => error),
    params: wrapParams(params)
  });
}

export const GraphComponent = connect(null, {pushModal})(React.createClass({
  export() {
    this.refs.graph.exportImage().then((url) => {
      this.props.pushModal({handler: ExportModal, props: {url}});
    });
  },

  render() {
    return (
      <div>
        <div className='graph' style={{position: 'relative'}}>
          {this.state.error ? <i className='fa fa-exclamation-triangle' stlye={{position: 'absolute', fontSize: '30px', top: '50%', transform: 'translate(-50%,-50%)', left: '50%'}}/> : null}
          <span className='fa-stack' title='Export' style={{position: 'absolute', top: '5px', right: '5px', cursor: 'pointer'}}>
            <i className='fa fa-square fa-stack-2x' style={{color: '#fff'}}/>
            <i className='fa fa-share-square-o fa-stack-1x' style={{color: '#ccc'}} onClick={this.export}/>
          </span>
          <WrappedGraphComponent params={this.state.params} data={this.state.data} ref='graph'/>
        </div>
        {this.state.error ? <Builtins.ErrorComponent message={this.state.error}/> : null}
      </div>
    );
  },

  componentWillReceiveProps(nextProps) {
    this._unsubscribe();
    this.subscribe(nextProps.model, this.state.graph);
  },

  getInitialState() {
    return {};
  },

  componentDidMount() {
    this.subscribe(this.props.model);
  },

  subscribe(model) {
    return this._unsubscribe = model.onValue(({data, params, error}) => {
      return this.setState({error, data, params});
    });
  },

  componentWillUnmount() {
    this._unsubscribe();
  }
}));
