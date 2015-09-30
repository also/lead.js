import React from 'react/addons';

import * as Context from '../context';
import * as CoffeeScriptCell from '../scripting/coffeescript';
import {SourceComponent} from '../components';
import ContextAwareMixin from '../context/ContextAwareMixin';
import _ from 'underscore';


export default React.createClass({
  mixins: [ContextAwareMixin, React.addons.PureRenderMixin],

  render() {
    const exampleComponent = <SourceComponent
      displayValue={this.props.displayValue}
      value={this.props.value}
      language='coffeescript'/>;

    const nestedContext = Context.create_nested_context(this.ctx(), {
      current_options: _.clone(this.ctx().options())
    });

    const fn = CoffeeScriptCell.create_fn(this.props.value);

    Context.run_in_context(nestedContext, fn);

    return (
      <div className='inline-example'>
        <div className='example'>
          {exampleComponent}
          <span className='run-button' onClick={this.onClick}>
            <i className='fa fa-play-circle'/> Edit this example
          </span>
        </div>
        <div className='output'>{nestedContext.component()}</div>
      </div>
    );
  },

  onClick() {
    return this.ctx().runScript(this.props.value);
  }
});
