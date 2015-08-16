import {Route, Routes, NotFoundRoute, Navigation} from 'react-router';
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
  render() {
    const {extraRoutes, ...extraProps} = this.props;
    return (
      <Routes>
        <Route handler={AppComponent} {...extraProps}>
          <Route path='/' name='default' handler={DefaultRoute}/>
          <Route name='notebook' handler={NewNotebookComponent}/>
          <Route path='/notebook/raw/*' name='raw_notebook' handler={Base64EncodedNotebookCellComponent} addHandlerKey={true}/>
          <Route path='/notebook/gist/*' name='gist_notebook' handler={GistNotebookComponent} addHandlerKey={true}/>
          <Route path='/notebook/github/*' name='github_notebook' handler={GitHubNotebookComponent} addHandlerKey={true}/>
          <Route path='/builder' handler={BuilderAppComponent}/>
          <Route path='/help' name='help-index' handler={HelpComponent}/>
          <Route path='/help/:key' name='help' handler={HelpComponent} addHandlerKey={true}/>
          <Route path='/github/oauth' handler={GitHub.GitHubOAuthComponent} addHandlerKey={true}/>
          <Route name='settings' handler={SettingsComponent}/>
          {extraRoutes}
          <NotFoundRoute handler={NotFoundComponent}/>
        </Route>
      </Routes>
    );
  }
});
