import * as React from 'react/addons';
import * as _ from 'underscore';

import ObjectBrowserComponent from '../ObjectBrowserComponent';
import {ToggleComponent} from '../components';

import ServerExceptionDetailsComponent from './ServerExceptionDetailsComponent';


export default React.createClass({
  render() {
    const {error} = this.props;

    const body = _.isArray(error)
      ? error.map((exception) => <ServerExceptionDetailsComponent exception={exception}/>)
      : <ServerExceptionDetailsComponent exception={error['unhandled-exception']}/>;

    return (
      <div>
        <strong>Server Error</strong>
        {body}
        <ToggleComponent title='Details'>
          <ObjectBrowserComponent object={error} showProto={false}/>
        </ToggleComponent>
      </div>
    );
  }
});
