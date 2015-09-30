import React from 'react';
import _ from 'underscore';
import CodeMirror from 'codemirror';

import AppAwareMixin from '../AppAwareMixin';
import * as CoffeeScriptCell from '../scripting/coffeescript';
import * as Context from '../context';
import TopLevelContextComponent from '../context/TopLevelContextComponent';
import ContextOutputComponent from '../context/ContextOutputComponent';
import {ToggleComponent} from '../components';
import {ObjectComponent} from '../builtins';
import EditorComponent from '../editor/EditorComponent';

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
  mixins: [AppAwareMixin],

  saveSettings(value) {
    const {app} = this.context;
    const fn = CoffeeScriptCell.create_fn(value != null ? value : this.refs.editor.get_value());
    const ctx = this.refs.ctx.get_ctx();

    Context.remove_all_components(ctx);

    const userSettings = fn(ctx);

    if (userSettings !== Context.IGNORE && _.isObject(userSettings)) {
      app.settings.user.set(userSettings);
    }
  },

  render() {
    const {app} = this.context;
    const {settings} = app;
    const initialValue = JSON.stringify(settings.user.get_without_overrides(), null, '  ');
    const {imports, modules} = app;
    const context = {app};

    const keyBindings = buildKeyMap();

    return <div className='settings output'>
      <ToggleComponent title='Default Settings'>
        <ObjectComponent object={settings.global.get_without_overrides()}/>
      </ToggleComponent>
      <ToggleComponent title='Key Map'>
        <KeyBindingComponent keys={keyBindings} commands={CodeMirror.commands}/>
      </ToggleComponent>
      <TopLevelContextComponent ref='ctx' {...{imports, modules, context}}>
        <div>
          <EditorComponent run={this.saveSettings} ref='editor' key='settings_editor' initial_value={initialValue}/>
          <ContextOutputComponent/>
        </div>
      </TopLevelContextComponent>
      <span className='run-button' onClick={() => this.saveSettings()}>
        <i className='fa fa-floppy-o'/>
        {' '}
        Save User Settings
      </span>
    </div>;
  }
});
