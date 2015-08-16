import * as React from 'react';
import moment from 'moment';

export default React.createClass({
  render() {
    const {gist: {owner, id, files, updated_at, html_url}} = this.props;

    const avatar = owner != null && owner.avatar_url != null ? owner.avatar_url : 'https://github.com/images/gravatars/gravatar-user-420.png';
    const username = owner != null && owner.login != null ? owner.login : 'anonymous';
    const filenames = Object.keys(files);
    filenames.sort();

    let title;
    if (filenames[0] === 'gistfile1.txt') {
      title = 'gist:' + id;
    } else {
      title = filenames[0];
    }

    let ownerLink;
    if (owner != null) {
      ownerLink = <a href={owner.html_url} target='_blank'>{username}</a>;
    } else {
      ownerLink = username;
    }

    return (
      <div className='gist-link'>
        <div className='creator'>
          <img src={avatar}/>
          {ownerLink}
          {' / '}
          <a href={html_url} target='_blank'>{title}</a>
        </div>
        <span className='datetime'>Saved {moment(updated_at).fromNow()}</span>
      </div>
    );
  }
});
