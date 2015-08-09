import * as _ from 'underscore';
import * as Bacon from 'bacon.model';
import * as React from 'react';

// FIXME static global
export const model = new Bacon.Model([]);

export function pushModal(modal) {
  window.setTimeout(() => {
    return model.modify((v) => v.concat(modal));
  }, 0);
  return modal;
}

export function removeModal(modal) {
  return window.setTimeout(() => {
    return model.modify((v) => _.without(v, modal));
  }, 0);
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
