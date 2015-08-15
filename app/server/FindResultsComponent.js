import * as React from 'react/addons';


export default React.createClass({
  render() {
    const {query, results, onClick} = this.props;

    const queryParts = query.split('.');

    return (
      <ul className='find-results'>{results.map((node, i) => {
        let text = node.path;
        if (!node.is_leaf) {
          text += '.*';
        }

        const nodeParts = text.split('.');

        return (
          <li key={i} className='cm-string' onClick={() => onClick(node)}>{nodeParts.map((segment, j) => {
            let s = segment;
            if (j > 0) {
              s = `.${s}`;
            }
            return <span key={j} className={segment === queryParts[j] ? 'light' : null}>{s}</span>;
          })}</li>
        );
      })}</ul>
    );
  }
});
