import React from 'react';
import _ from 'underscore';
import CodeMirror from 'codemirror';

import {AppAwareMixin} from './app';
import CoffeeScriptCell from './coffeescript_cell';
import * as Context from './context';
import Settings from './settings';
import {ToggleComponent} from './components';
import {ObjectComponent} from './builtins';
import {EditorComponent} from './editor';

const buildKeyMap = function () {
  const allKeys = {};
  // TODO some commands are functions instead of names
  const buildMap = function (map) {
    for (const key in map) {
      const command = map[key];
      const fn = CodeMirror.commands[command];
      if (key !== 'fallthrough' && allKeys[key] == null && fn != null) {
        allKeys[key] = {name: command, doc: fn.doc};
      }
    }

    if (map.fallthrough != null) {
      map.fallthrough.forEach((name) => buildMap(CodeMirror.keyMap[name]));
    }
  };

  buildMap(CodeMirror.keyMap.notebook);

  return allKeys;
};

const KeySequenceComponent = React.createClass({
  displayName: 'KeySequenceComponent',

  render() {
    return <span>
      {_.map(this.props.keys, (k) => <kbd>{k}</kbd>)}
    </span>;
  }
});

const KeyBindingComponent = React.createClass({
  displayName: 'KeyBindingComponent',

  render() {
    return <table>{_.map(this.props.keys, (command, key) => {
      return <tr>
        <th><KeySequenceComponent keys={key.split('-')}/></th>
        <td><strong>{command.name}</strong></td>
        <td>{command.doc}</td>
      </tr>;
    })}</table>;
  }
});

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

    const keyBindings = buildKeyMap();

    return <div className="settings output">
      <ToggleComponent title="Default Settings">
        <ObjectComponent object={Settings.get_without_overrides()}/>
      </ToggleComponent>
      <ToggleComponent title="Key Map">
        <KeyBindingComponent keys={keyBindings} commands={CodeMirror.commands}/>
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
