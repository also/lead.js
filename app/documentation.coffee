React = require './react_abuse'
_ = require 'underscore'
Markdown = require './markdown'

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

DocumentationIndexComponent = React.createClass
  show_help: (key) ->
    if _.isArray key
      key = key.join '.'
    @props.ctx.run "help '#{key}'"
  render: ->
    React.DOM.table {}, _.map @props.entries, (e) =>
      React.DOM.tr {},
        React.DOM.td {}, React.DOM.code {className: 'run-link', onClick: => @show_help e.key ? e.name}, e.name
        React.DOM.td {}, Documentation.summary @props.ctx, e.doc

DocumentationItemComponent = React.createClass
  render: ->
    complete_docs = Documentation.complete(@props.ctx, @props.doc) or Documentation.summary(@props.ctx, @props.doc)
    React.DOM.div {},
      complete_docs

Documentation =
  DocumentationItemComponent: DocumentationItemComponent
  DocumentationIndexComponent: DocumentationIndexComponent
  register_documentation: (key, doc) ->
    key = normalize_key key
    doc = _.extend {key}, doc
    get_parent(key)._lead_doc = doc

  get_documentation: (key) ->
    get_parent(normalize_key key)._lead_doc

  keys: (key) ->
    _.filter _.map(get_parent(normalize_key key), (v, k) -> if v._lead_doc? then k else null), _.identity

  # TODO the ctx passed to summary, complete, etc should not be appendable
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
    else if _.isString doc.complete
      Markdown.LeadMarkdownComponent value: doc.complete, ctx: ctx
    else if doc.index
      Documentation.index ctx, doc.key
    else
      doc.complete

  index: (ctx, key) ->
    key = normalize_key key
    keys = Documentation.keys key
    DocumentationIndexComponent {ctx, entries: _.map(keys, (k) ->
      entry_key = key.concat(k)
      name: k, key: entry_key, doc: Documentation.get_documentation entry_key)}

module.exports = Documentation
