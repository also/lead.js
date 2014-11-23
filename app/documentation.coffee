React = require 'react'
Router = require 'react-router'
_ = require 'underscore'
Markdown = require './markdown'
Context = require './context'
ContextComponents = require './contextComponents'

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

resolve_key = (ctx, o) ->
  resolvers = Context.collect_extension_points ctx, 'resolve_documentation_key'
  result = null
  _.find resolvers, (resolver) ->
    key = resolver ctx, o
    if key and Documentation.get_documentation key
      result = key
  result

DocumentationLinkComponent = React.createClass
  displayName: 'DocumentationLinkComponent'
  mixins: [ContextComponents.ContextAwareMixin]
  show_help: ->
    Documentation.navigate @state.ctx, @props.key
  render: ->
    React.DOM.span {className: 'run-link', onClick: @show_help}, @props.children

DocumentationIndexComponent = React.createClass
  displayName: 'DocumentationIndexComponent'
  render: ->
    React.DOM.table {}, _.map @props.entries, (e) =>
      key = e.key ? e.name
      React.DOM.tr {key},
        React.DOM.td {}, DocumentationLinkComponent {key}, React.DOM.code null, e.name
        React.DOM.td {}, Documentation.summary @props.ctx, e.doc

DocumentationItemComponent = React.createClass
  render: ->
    complete_docs = Documentation.complete(@props.ctx, @props.doc) or Documentation.summary(@props.ctx, @props.doc)
    React.DOM.div {},
      complete_docs

Documentation =
  DocumentationLinkComponent: DocumentationLinkComponent
  DocumentationItemComponent: DocumentationItemComponent
  DocumentationIndexComponent: DocumentationIndexComponent

  key_to_string: (key) ->
    if _.isArray key
      key.join '.'
    else
      key

  navigate: (ctx, key) ->
    key = Documentation.key_to_string key
    if ctx.docs_navigate?
      ctx.docs_navigate key
    else
      ctx.run "help '#{key}'"

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
      Markdown.LeadMarkdownComponent value: doc.complete
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

  get_key: (ctx, o) ->
    if !o?
      return ['main']
    if _.isString o
      key
      doc = Documentation.get_documentation o
      if doc?
        return o
      else
        scoped = Context.find_in_scope ctx, o
        if scoped
          key = resolve_key ctx, scoped
        else
          key = resolve_key ctx, o
    else
      key = resolve_key ctx, o

    return null unless key

    if Documentation.get_documentation key
      return key
    else
      return null

  load_file: (name) ->
    # TODO run in node
    if process.browser
      ->
        {images, content} = require "../lib/markdown-loader.coffee!../docs/#{name}.md"
        Markdown.LeadMarkdownComponent
          value: content
          image_urls: images

  register_file: (name, key) ->
    Documentation.register_documentation key ? name, complete: Documentation.load_file name

  key_to_path: normalize_key

Documentation.register_file 'quickstart'
Documentation.register_file 'style'
Documentation.register_documentation 'main', complete: '''
# lead.js Documentation

* [Quick Start](help:quickstart)
* [lead.js Functions](help:imported_context_fns)
* [Server Functions](help:server.functions)

## Top Functions

* [`graph`](help:graphing.graph)
* [`q`](help:server.q)
* [`save_gist`](help:github.save_gist)
* [`tsd`](help:opentsdb.tsd)
'''

Documentation.register_documentation 'imported_context_fns', complete: (ctx, doc) ->
  fn_docs = _.map ctx.imported_context_fns, (fn, name) ->
    if fn?
      key = [fn.module_name, fn.name]
      doc = Documentation.get_documentation key
      if doc?
        {name, doc, key}
  documented_fns = _.sortBy _.filter(fn_docs, _.identity), 'name'
  Documentation.DocumentationIndexComponent entries: documented_fns, ctx: ctx

Documentation.register_documentation 'module_list', complete: (ctx, doc) ->
  module_docs = _.sortBy _.map(_.keys(ctx.modules), (name) -> {name, doc: {summary: ''}}), 'name'
  Documentation.DocumentationIndexComponent entries: module_docs, ctx: ctx

_.extend exports, Documentation
