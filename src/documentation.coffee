define (require) ->
  React = require 'react_abuse'
  _ = require 'underscore'

  docs = {}

  get_parent = (key) ->
    parent = docs
    for segment in key
      parent = parent[segment] ?= {}
    parent

  normalize_key = (key) ->
    if _.isArray key
      key
    else
      key.split '.'

  register_documentation: (key, doc) ->
    get_parent(normalize_key key)._lead_doc = doc

  get_documentation: (key) ->
    get_parent(normalize_key key)._lead_doc

  summary: (ctx, doc) ->
    if _.isFunction doc.summary
      doc.summary ctx, doc
    else if _.isString doc.summary
      React.DOM.p {}, doc.summary
    else
      doc.summary

  complete: (ctx, doc) ->
    if _.isFunction doc.complete
      doc.complete ctx, doc
    else
      doc.complete
