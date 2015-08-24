import * as Bacon from 'bacon.model';
import React from 'react/addons';

import * as Context from '../context';
import * as Settings from '../settings';

import DocumentComponent from './DocumentComponent';

function createNotebook(opts) {
  const cells_model = Bacon.Model([]);
  const model = Bacon.Model.combine({
    cells: cells_model,
    settings: Settings.toModel('notebook')
  });

  const notebook = {
    model: model,
    context: opts.context,
    cells: [],
    cells_model,
    input_number: 1,
    output_number: 1,
    cell_run: new Bacon.Bus(),
    cell_focused: new Bacon.Bus()
  };

  if (process.browser) {
    const bodyElt = document.querySelector('.body');
    const scrolls = Bacon.fromEventTarget(bodyElt, 'scroll');
    const scroll_to = notebook.cell_run.flatMapLatest(function (input_cell) {
      return input_cell.output_cell.done.delay(0).takeUntil(scrolls);
    });

    scroll_to.onValue(function (output_cell) {
      const bodyTop = bodyElt.getBoundingClientRect().top;
      const bodyScroll = bodyElt.scrollTop;

      bodyElt.scrollTop = output_cell.dom_node.getBoundingClientRect().top - bodyTop + bodyScroll;
    });
  }
  const base_context = Context.create_base_context(opts);

  notebook.base_context = base_context;
  return notebook;
}


export default React.createClass({
  propTypes: {
    imports: React.PropTypes.arrayOf(React.PropTypes.string).isRequired,
    modules: React.PropTypes.object.isRequired,
    init: React.PropTypes.func
  },

  getInitialState() {
    const notebook = createNotebook(this.props);

    const {init} = this.props;
    if (init) {
      init(notebook);
    }
    return {notebook};
  },

  shouldComponentUpdate() {
    return false;
  },

  render() {
    const {notebook} = this.state;
    return <DocumentComponent notebook={notebook}/>;
  }
});
