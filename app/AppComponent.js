import * as React from 'react';
import * as Router from 'react-router';
import {connect} from 'react-redux';

import * as Modal from './modal';

// react-router needs this to be impure?
export default connect((state) => ({coreInit: state.get('coreInit')}), null, null, {pure: false})(React.createClass({
  displayName: 'AppComponent',
  childContextTypes: {
    app: React.PropTypes.object
  },

  mixins: [Router.Navigation],

  getChildContext() {
    return {
      app: this.props.app
    };
  },

  getInitialState() {
    return {
      modal: null
    };
  },

  componentWillMount() {
    return Modal.model.onValue((modals) => {
      return this.setState({
        modal: modals[modals.length - 1]
      });
    });
  },

  toggleFullscreen() {
    if (document.fullscreenElement || document.mozFullScreenElement || document.webkitFullscreenElement) {
      const f = document.exitFullscreen || document.mozCancelFullScreen || document.webkitExitFullscreen;
      return f.call(document);
    } else {
      const n = document.documentElement;
      const f = n.requestFullscreen || n.mozRequestFullScreen || n.webkitRequestFullscreen;
      if (f != null) {
        f.call(n);
      }
    }
  },

  render() {
    const {bodyWrapper, coreInit} = this.props;
    this.props.app.appComponent = this;
    const {modal} = this.state;

    let body = coreInit.get('state') === 'pending' ? null : <Router.RouteHandler/>;

    if (bodyWrapper) {
      body = React.createElement(bodyWrapper, null, body);
    }

    return (
      <div className='lead'>
        <div className='nav-bar'>
          <Router.Link to='notebook' className='title'>lead</Router.Link>
          <div className='menu'>
            <Router.Link to='help-index'><i className='fa fa-question-circle'/></Router.Link>
            <Router.Link to='settings'><i className='fa fa-cog'/></Router.Link>
            <i className='fa fa-expand' onClick={this.toggleFullscreen}/>
          </div>
        </div>
        <div className='body'>{body}</div>
        {modal ? (
          <div className='modal-bg'>
            <div className='modal-fg'>
              <modal.handler dismiss={() => Modal.removeModal(modal)} {...modal.props}/>
            </div>
          </div>
        ) : null}
      </div>
    );
  }
}));
