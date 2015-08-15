import React from 'react/addons';

import {ObservableMixin} from '../components';
import * as Editor from '../editor';
import * as Builtins from '../builtins';
import * as Context from '../context';
import {run_without_input_cell} from '../notebook';


function generatePermalink(cell) {
  run_without_input_cell(cell.notebook, {
    after: cell.output_cell || cell
  }, function (ctx) {
    Builtins.contextExports.permalink.fn(ctx);
    return Context.IGNORE;
  });
}

export default React.createClass({
  displayName: 'InputCellComponent',
  mixins: [ObservableMixin, React.addons.PureRenderMixin],
  getObservable(props) {
    return props.cell.changes;
  },
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
    return generatePermalink(this.props.cell);
  }
});
