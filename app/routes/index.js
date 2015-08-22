import {Route, NotFoundRoute, Navigation} from 'react-router';
import * as Router from 'react-router';
import * as React from 'react';

import AppComponent from '../appComponent';
import SettingsComponent from '../settings/SettingsEditor';
import * as GitHub from '../github';

import NotFoundComponent from './notFoundComponent';
import NewNotebookComponent from './newNotebookComponent';
import HelpComponent from './helpComponent';
import GitHubNotebookComponent from './gitHubNotebookComponent';
import GistNotebookComponent from './gistNotebookComponent';
import Base64EncodedNotebookCellComponent from './base64EncodedNotebookCellComponent';
import BuilderAppComponent from './builderAppComponent';


function wrapComponent(Component, props) {
  return React.createClass({
    render() {
      return React.createElement(Component, props);
    }
  });
}

const DefaultRoute = React.createClass({
  mixins: [Navigation],

  render() {
    const queryKeys = Object.keys(this.props.query);

    if (queryKeys.length === 1 && this.props.query[queryKeys[0]].length === 0) {
      return this.replaceWith('/notebook/raw/' + queryKeys[0]);
    } else {
      return this.transitionTo('notebook');
    }
  }
});

export default React.createClass({
  getInitialState() {
    return {Handler: null};
  },

  componentWillMount() {
    const {extraRoutes, ...extraProps} = this.props;
    const routes = (
      <Route handler={wrapComponent(AppComponent, extraProps)}>
        <Route path='/' name='default' handler={DefaultRoute}/>
        <Route name='notebook' handler={NewNotebookComponent}/>
        <Route path='/notebook/raw/*' name='raw_notebook' handler={Base64EncodedNotebookCellComponent}/>
        <Route path='/notebook/gist/*' name='gist_notebook' handler={GistNotebookComponent}/>
        <Route path='/notebook/github/*' name='github_notebook' handler={GitHubNotebookComponent}/>
        <Route path='/builder' handler={BuilderAppComponent}/>
        <Route path='/help' name='help-index' handler={HelpComponent}/>
        <Route path='/help/:docKey' name='help' handler={HelpComponent}/>
        <Route path='/github/oauth' handler={GitHub.GitHubOAuthComponent}/>
        <Route name='settings' handler={SettingsComponent}/>
        {extraRoutes}
        <NotFoundRoute handler={NotFoundComponent}/>
      </Route>
    );

    Router.run(routes, (Handler) => this.setState({Handler}));
  },

  render() {
    const {Handler} = this.state;
    return <Handler/>;
  }
});
