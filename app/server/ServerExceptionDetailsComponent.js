import * as React from 'react/addons';


export default React.createClass({
  render() {
    const {exception} = this.props;

    return (
      <div>
        <div>
          <strong>{exception.message}</strong>
          {exception.details && exception.details.message ? <div>{exception.details.message}</div> : null}
        </div>
      </div>
    );
  }
});
