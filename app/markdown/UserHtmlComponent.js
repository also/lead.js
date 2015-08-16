import React from 'react/addons';


export default React.createClass({
  displayName: 'UserHtmlComponent',
  render() {
    return <div className='user-html' dangerouslySetInnerHTML={{__html: this.props.html}}/>
  }
});
