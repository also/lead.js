jsdom = require 'jsdom'

module.exports = (grunt) ->
  parse_graphite_html = (file) ->
    jsdom.html(grunt.file.readJSON(file).body, null, features: QuerySelector: true)

  grunt.registerTask 'graphite', 'Prepare Graphite Docs', ->
    html = parse_graphite_html 'render_api.fjson'
    parameters = html.querySelector 'div#graph-parameters'
    a.parentNode.removeChild(a) for a in parameters.querySelectorAll 'a.headerlink'
    parameter_docs = {}
    parameter_doc_ids = {}
    for section in parameters.querySelectorAll 'div.section'
      name = section.querySelector('h3').textContent
      parameter_docs[name] = section.innerHTML
      parameter_doc_ids[section.id] = name

    prefix_length = "graphite.render.functions.".length

    html = parse_graphite_html 'functions.fjson'
    function_docs = {}
    for tag in html.getElementsByTagName 'dt'
      for a in tag.getElementsByTagName 'a'
        a.parentNode.removeChild(a)
      dl = tag.parentNode
      signature = tag.textContent.trim()
      examples = []
      for pre in dl.getElementsByTagName 'pre'
        for line in pre.textContent.split '\n'
          if line.indexOf('&target=') == 0
            examples.push line[8..]
      function_docs[tag.id[prefix_length..]] = {signature, examples, docs: dl.outerHTML}

    result = {parameter_docs, parameter_doc_ids, function_docs}
    grunt.file.write 'lib/graphite_docs.js', "module.exports = #{JSON.stringify result};"
