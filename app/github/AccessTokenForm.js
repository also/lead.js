import * as React from 'react';

export default React.createClass({
  handleSet() {
    return this.props.handle_token(this.refs.input.getDOMNode().value);
  },

  render() {
    return (
      <div>
        <p>Access Token: <input ref='input'/> <button onClick={this.handleClick}>Set</button></p>
      </div>
    );
  }
});
