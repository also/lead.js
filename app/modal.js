import * as React from 'react';
import * as actions from './actions';

export function pushModal(ctx, modal) {
  ctx.app.store.dispatch(actions.pushModal(modal));
  return modal;
}

export function removeModal(ctx, modal) {
  ctx.app.store.dispatch(actions.removeModal(modal));
}

export const ModalComponent = React.createClass({
  render() {
    const {title, children, footer} = this.props;

    return (
      <div>
        {title ? <div className='modal-title'>{title}</div> : null}
        <div className='modal-content'>{children}</div>
        {footer ? <div className='modal-footer'>{footer}</div> : null}
      </div>
    );
  }
});
