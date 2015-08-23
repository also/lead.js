import _ from 'underscore';
import React from 'react';
import Bacon from 'bacon.model';

import * as modules from './modules';
import * as Context from './context';
import {ObservableMixin} from './components';


const InputMixin = Object.assign({}, ObservableMixin, {
  getObservable(props) {
    return props.model;
  },

  handleChange(e) {
    return this.props.model.set(e.target.value);
  }
});

// creates an input component bound to a bacon model
// changes to the input component will update the model and changes to the
// model will update the input component
function createComponent(constructor, props) {
  const model = Bacon.Model(props.defaultValue ? String(props.defaultValue) : '');
  props = Object.assign(props, {model});
  const component = React.createElement(constructor, props);

  return {component, model};
}

const SelectComponent = React.createClass({
  displayName: 'SelectComponent',

  mixins: [InputMixin],

  render() {
    const {options} = this.props;
    const {value} = this.state;

    return (
      <select value={value} onChange={this.handleChange}>
        {options.map((o) => {
          let k;
          let v;
          if (_.isArray(o)) {
            [k, v] = o;
          } else {
            k = v = o;
          }
          return <option value={k}>{v}</option>;
        })}
      </select>
    );
  }
});

const InputComponent = React.createClass({
  displayName: 'InputComponent',

  mixins: [InputMixin],

  render() {
    return <input {...{
      type: this.props.type,
      value: this.state.value,
      onChange: this.handleChange
    }}/>;
  }
});

modules.export(exports, 'input', ({fn}) => {
  fn('text_input', 'A text input field', (ctx, defaultValue='') => {
    const {component, model} = createComponent(InputComponent, {
      type: 'text',
      defaultValue: defaultValue
    });

    Context.add_component(ctx, component);
    return Context.value(model);
  });

  fn('select', 'A select field', (ctx, options, defaultValue) => {
    if (!defaultValue) {
      const v = options[0];
      defaultValue = _.isArray(v) ? v[0] : v;
    }

    const {component, model} = createComponent(SelectComponent, {
      options: options,
      defaultValue: defaultValue
    });

    Context.add_component(ctx, component);
    return Context.value(model);
  });

  fn('button', 'A button', (ctx, value) => {
    const bus = new Bacon.Bus();
    const button = <button onClick={(e) => bus.push(e)}>{value}</button>;

    Context.add_component(ctx, button);
    return Context.value(bus);
  });

  fn('live', 'Updates when the property changes', (ctx, property, wrappedFn) => {
    Context.nested_item(ctx, (ctx) => {
      if (property.onValue == null) {
        property = Bacon.combineTemplate(property);
      }
      return property.onValue((v) => {
        Context.remove_all_components(ctx);
        return Context.callUserFunctionInCtx(ctx, wrappedFn, [v]);
      });
    });
  });
});
