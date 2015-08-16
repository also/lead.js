import Marked from 'marked';
import React from 'react/addons';
import URI from 'URIjs';
import _ from 'underscore';
import * as Components from '../components';
import {ContextAwareMixin} from '../contextComponents';
import * as Documentation from '../documentation';
import UserHtmlComponent from './UserHtmlComponent';
import InlineExampleComponent from  './InlineExampleComponent';


export default React.createClass({
  displayName: 'LeadMarkdownComponent',
  mixins: [ContextAwareMixin],
  getDefaultProps() {
    return {image_urls: {}};
  },

  getInitialState() {
    // FIXME #175 props can change
    const {image_urls} = this.props;

    const renderer = new Marked.Renderer();
    const imageRenderer = renderer.image.bind(renderer);

    renderer.image = (href, title, text) => imageRenderer(image_urls[href] || href, title, text);

    const opts = _.defaults({renderer}, Marked.defaults);

    const tokens = Marked.Lexer.lex(this.props.value, Marked.defaults);

    let currentTokens = [];
    const components = [];
    let codePrefix = null;
    let nextCodeOptions = {};

    tokens.forEach((t) => {
      if (t.type === 'html') {
        const trimmed = t.text.trim();

        if (trimmed === '<!-- norun -->') {
          nextCodeOptions.norun = true;
        } else if (trimmed === '<!-- noinline -->') {
          nextCodeOptions.noinline = true;
        } else if (trimmed === '<!-- code-prefix -->') {
          nextCodeOptions.codePrefix = true;
        } else if (trimmed === '<!-- skip-code-prefix -->') {
          nextCodeOptions.skipCodePrefix = true;
        } else {
          currentTokens.push(t);
        }
      } else if (t.type === 'code') {
        if (currentTokens.length > 0) {
          currentTokens.links = tokens.links;
          components.push(<UserHtmlComponent html={Marked.Parser.parse(currentTokens, opts)}/>);
          currentTokens = [];
        }
        const value = t.text.trim();

        let script;
        if (codePrefix != null && !nextCodeOptions.skipCodePrefix) {
          script = codePrefix + '\n' + value;
        } else {
          script = value;
        }

        if (nextCodeOptions.norun) {
          components.push(
            <Components.SourceComponent
              displayValue={value}
              value={script}
              language='coffeescript'/>
          );
        } else if (nextCodeOptions.noinline) {
          components.push(
            <Components.ExampleComponent
              displayValue={value}
              value={script}
              run={true}/>
          );
        } else if (nextCodeOptions.codePrefix) {
          codePrefix = value;
        } else {
          components.push(<InlineExampleComponent displayValue={value} value={script}/>);
        }
        nextCodeOptions = {};
      } else {
        currentTokens.push(t);
      }
    });

    if (currentTokens.length > 0) {
      currentTokens.links = tokens.links;

      components.push(<UserHtmlComponent html={Marked.Parser.parse(currentTokens, opts)}/>);
    }
    return {components};
  },

  render() {
    return <div className='lead-markdown'>{this.state.components}</div>;
  },

  componentDidMount() {
    for (const a of this.getDOMNode().querySelectorAll('a')) {
      a.addEventListener('click', (e) => {
        const uri = new URI(a.href);

        if (uri.protocol() === 'help') {
          e.preventDefault();
          return Documentation.navigate(this.state.ctx, uri.path());
        }
      });
    }
  }
});
