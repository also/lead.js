import React from 'react/addons';

import * as Editor from '../editor';
import * as Builtins from '../builtins';
import * as Context from '../context';
import {runWithoutInputCell} from '../notebook';
import ContextAwareMixin from '../context/ContextAwareMixin';


function generatePermalink(ctx, cell) {
  runWithoutInputCell(ctx, {
    after: cell.outputCell || cell
  }, (ctx) => {
    Builtins.scriptingExports.permalink.fn(ctx);
    return Context.IGNORE;
  });
}

export default React.createClass({
  mixins: [React.addons.PureRenderMixin, ContextAwareMixin],

  render() {
    const {cell} = this.props;
    return (
      <div className='cell input' data-cell-number={cell.number}>
        <div className='code' ref='code'/>
        <div className='input-menu'>
          <span className='permalink' onClick={this.permalinkLinkClicked}><i className='fa fa-link'/></span>
        </div>
      </div>
    );
  },

  updateHeight(minHeight) {
    return Editor.setMinHeight(this.props.cell.editor, minHeight);
  },

  componentDidMount() {
    const editor = this.props.cell.editor;

    this.refs.code.getDOMNode().appendChild(editor.display.wrapper);
    editor.refresh();
    return this.updateHeight(this.props.minHeight);
  },

  componentWillUpdate(newProps) {
    return this.updateHeight(newProps.minHeight);
  },

  permalinkLinkClicked() {
    return generatePermalink(this.ctx(), this.props.cell);
  }
});
