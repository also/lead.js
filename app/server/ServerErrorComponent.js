import * as React from 'react/addons';
import * as _ from 'underscore';

import {ObjectBrowserComponent} from '../objectBrowser';
import {ToggleComponent} from '../builtins';

import ServerExceptionDetailsComponent from './ServerExceptionDetailsComponent';

// ServerErrorComponent = React.createClass
//   render: ->
//     if _.isArray @props.error
//       body = _.map @props.error, (exception) -> ServerExceptionDetailsComponent {exception}
//     else if @props.error['unhandled-exception']
//       body = ServerExceptionDetailsComponent {exception: @props.error['unhandled-exception']}
//
//     React.DOM.div {},
//       React.DOM.strong {}, 'Server Error',
//         body
//         Components.ToggleComponent {title: 'Details'},
//           Builtins.ObjectBrowserComponent {object: @props.error, showProto: false}
//

export default React.createClass({
  render() {
    const {error} = this.props;

    const body = _.isArray(error)
      ? error.map(exception => <ServerExceptionDetailsComponent exception={exception}/>)
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
