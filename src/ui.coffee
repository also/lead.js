define (require) ->
  modules = require 'modules'

  tooltip: (contents, mouse_event) ->
    elt = document.createElement 'div'
    elt.className = 'tooltip'
    elt.innerText = contents
    elt.style.top = mouse_event.pageY + 20 + 'px'
    elt.style.left = mouse_event.pageX + 10 + 'px'
    document.body.appendChild elt
    ->
      document.body.removeChild elt

