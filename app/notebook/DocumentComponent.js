import React from 'react/addons';

import {ObservableMixin} from '../components';

import InputOutputComponent from './InputOutputComponent';


export default React.createClass({
  mixins: [ObservableMixin],

  getObservable(props) {
    return props.notebook.model;
  },

  render() {
    const {settings={layout: 'repl'}, cells} = this.state.value;
    const {layout} = settings;
    const useMinHeight = layout === 'two-column';

    const ios = [];
    let props = null;
    cells.forEach((cell) => {
      if (cell.type === 'input') {
        props = {
          input_cell: cell,
          key: cell.key,
          useMinHeight: useMinHeight
        };
        ios.push(props);
      } else {
        if (props == null || props.input_cell.output_cell !== cell) {
          ios.push({
            output_cell: cell,
            key: cell.key,
            useMinHeight: useMinHeight
          });
        } else {
          props.output_cell = cell;
        }
        props = null;
      }
    });

    return (
      <div className={`notebook ${layout}-style`}>
        {ios.map((io) => <InputOutputComponent {...io}/>)}
      </div>
    );
  }
});
