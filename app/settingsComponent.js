import React from 'react';
import _ from 'underscore';

import {AppAwareMixin} from './app';
import CoffeeScriptCell from './coffeescript_cell';
import * as Context from './context';
import Settings from './settings';
import {ToggleComponent} from './components';
import {ObjectComponent} from './builtins';
import {EditorComponent} from './editor';

export default React.createClass({
  displayName: 'SettingsComponent',

  mixins: [AppAwareMixin],

  saveSettings(value) {
    const fn = CoffeeScriptCell.create_fn(value != null ? value : this.refs.editor.get_value());
    const ctx = this.refs.ctx.get_ctx();

    Context.remove_all_components(ctx);

    const userSettings = fn(ctx);

    if (userSettings !== Context.IGNORE && _.isObject(userSettings)) {
      Settings.user_settings.set(userSettings);
    }
  },

  render() {
    const initialValue = JSON.stringify(Settings.user_settings.get_without_overrides(), null, '  ');
    const {imports, modules} = this.context.app;
    const context = {app: this.context.app};

    return <div className="settings output">
      <ToggleComponent title="Default Settings">
        <ObjectComponent object={Settings.get_without_overrides()}/>
      </ToggleComponent>
      <Context.TopLevelContextComponent ref="ctx" {...{imports, modules, context}}>
        <EditorComponent run={this.saveSettings} ref="editor" key="settings_editor" initial_value={initialValue}/>
        <Context.ContextOutputComponent/>
      </Context.TopLevelContextComponent>
      <span className="run-button" onClick={() => this.saveSettings()}>
        <i className="fa fa-floppy-o"/>
        {' '}
        Save User Settings
      </span>
    </div>;
  }
});
