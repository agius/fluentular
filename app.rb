# enoding: utf-8

require 'sinatra'
require 'sinatra/json'
require 'fluent/version'
require 'fluent/log'
require 'fluent/config'
require 'fluent/engine'
require 'fluent/parser'

set :haml, format: :html5

get '/' do
  haml :index
end

get '/parse.?:format?' do
  # Request params
  @regexp      = params[:regexp].gsub(%r{^\/(.+)\/$}, '\1')
  @input       = params[:input]
  @time_format = params[:time_format]

  # Response data
  @error       = nil
  @parsed      = {}
  @parsed_time = nil

  begin
    parser = Fluent::TextParser::RegexpParser.new(Regexp.new(@regexp))
    parser.configure('time_format' => @time_format) unless @time_format.empty?
    @parsed_time, @parsed = parser.call(@input)
  rescue Fluent::TextParser::ParserError, RegexpError => e
    @error = e
  end

  if params[:format] == 'json'
    json parsed_time: @parsed_time, parsed: @parsed.to_json, error: @error
  else
    haml :index
  end
end

__END__

@@ index
!!!
%html
  %head
    %meta(charset='UTF-8')
    %meta(name='viewport' content='width=device-width, initial-scale=1.0')
    %title Fluentular: a Fluentd regular expression editor
    %link(rel='stylesheet' href='//netdna.bootstrapcdn.com/font-awesome/4.1.0/css/font-awesome.min.css')
    %link(rel='stylesheet' href='//cdnjs.cloudflare.com/ajax/libs/foundation/5.5.0/css/normalize.min.css')
    %link(rel='stylesheet' href='//cdnjs.cloudflare.com/ajax/libs/foundation/5.5.0/css/foundation.min.css')
    %script(src='//cdnjs.cloudflare.com/ajax/libs/modernizr/2.8.3/modernizr.min.js')
    %script(src='//cdnjs.cloudflare.com/ajax/libs/react/0.13.1/JSXTransformer.js')
    %script(src='//cdnjs.cloudflare.com/ajax/libs/react/0.13.1/react.min.js')
    %script(src='//cdnjs.cloudflare.com/ajax/libs/superagent/0.15.7/superagent.min.js')
    %script(src='//cdnjs.cloudflare.com/ajax/libs/URI.js/1.11.2/URI.min.js')
    :javascript
      var _gaq = _gaq || [];
      _gaq.push(['_setAccount', "#{ENV['UA_CODE']}"]);
      _gaq.push(['_trackPageview']);
      (function() {
        var ga = document.createElement('script');
        ga.type = 'text/javascript'; ga.async = true;
        ga.src = ('https:' == document.location.protocol ? 'https://ssl' : 'http://www') + '.google-analytics.com/ga.js';
        var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(ga, s);
      })();
    %script(type='text/jsx')
      :plain
        var request = window.superagent;

        var FluentularApp = React.createClass({
          getInitialState: function() {
            return { error: null };
          },
          componentDidMount: function() {
            var uri = URI.parse(location.href);
            if (uri.query == null) {
              return;
            }

            var data = URI.parseQuery(uri.query);
            request.get(
              '/parse.json', data, (res) => {
                this.setProps(data);
                this.setState(res.body);
            });
          },
          onChangeTextArea: function(e) {
            var data = this.props;
            data[e.target.name] = e.target.value;
            this.setProps(data);
          },
          onSubmit: function(e) {
            e.preventDefault();
            var regexp      = React.findDOMNode(this.refs.regexp).value;
            var input       = React.findDOMNode(this.refs.input).value;
            var time_format = React.findDOMNode(this.refs.time_format).value;
            if (!regexp || !input) {
              return;
            }

            request.get(
              '/parse.json',
              { regexp: regexp, input: input, time_format: time_format }, (res) => {
                this.setState(res.body);
            });
          },
          render: function() {
            var errorMessage;
            if (this.state.error != null) {
              errorMessage = <ErrorMessage error={this.state.error} />
            }
            return (
              <div class="container">
                <div className="row">
                  <section className="small-12 medium-8 columns">
                    <form action="/parse" onSubmit={this.parse}>
                      <label><i className="fa fa-code"></i>Regular Expression</label>
                      <textarea ref="regexp" name="regexp" rows="5" value={this.props.regexp} onChange={this.onChangeTextArea}></textarea>
                      <label><i className="fa fa-quote-left"></i>Test String</label>
                      <textarea ref="input" name="input" rows="5" value={this.props.input} onChange={this.onChangeTextArea}></textarea>
                      <label><i className="fa fa-clock-o"></i>
                        Custom Time Format (see also ruby document;
                        <a href="http://docs.ruby-lang.org/en/2.2.0/Time.html#method-i-strptime">strptime</a>
                        )
                      </label>
                      <textarea ref="time_format" name="time_format" rows="1" value={this.props.time_format} onChange={this.onChangeTextArea}></textarea>
                      {errorMessage}
                      <div className="row">
                        <div className="large-2 large-centered columns">
                          <input className="radius button" type="submit" value="Parse" />
                        </div>
                      </div>
                    </form>
                  </section>

                  <Panel />
                </div>

                <Configuration regexp={this.props.regexp} time_format={this.props.time_format}/>
              </div>
            );
          }
        });

        var ErrorMessage = React.createClass({
          render: function () {
            return (
              <span className="alert-box alert radius">
                <i className="fa fa-exclamation-triangle"></i> Error: {this.props.error}
              </span>
            );
          }
        });

        var Panel = React.createClass({
          render: function() {
            return (
              <aside className="small-12 medium-4 columns">
                <div className="panel callout radius">
                  <h4>Example (Aapache)</h4>
                  <h6>Regular Expression:</h6>
                  <pre>
                    ^(?&lt;host&gt;[^ ]*) [^ ]* (?&lt;user&gt;[^ ]*) \[(?&lt;time&gt;[^\]]*)\] "(?&lt;method&gt;\S+)(?: +(?&lt;path&gt;[^ ]*) +\S*)?" (?&lt;code&gt;[^ ]*) (?&lt;size&gt;[^ ]*)(?: "(?&lt;referer&gt;[^\"]*)" "(?&lt;agent&gt;[^\"]*)")?$
                  </pre>
                  <br />
                  <h6>Time Format:</h6>
                  <pre>
                    %d/%b/%Y:%H:%M:%S %z
                  </pre>
                </div>
              </aside>
            );
          }
        });

        var Configuration = React.createClass({
          render: function() {
            var time_format_template;
            if (this.props.time_format != null && this.props.time_format != '') {
              time_format_template = <TimeFormatTemplate time_format={this.props.time_format} />
            }

            return (
              <div className="row">
                <section className="small-12 small-centered columns">
                  <h3><i className="fa fa-file-code-o"></i> Configuration</h3>
                  <p>Copy and paste to <code>fluent.conf</code> or <code>td-agent.conf</code></p>
                  <div className="panel">
                    &lt;/source&gt;
                    <br />
                    &nbsp;&nbsp;type tail
                    <br />
                    &nbsp;&nbsp;path /var/log/foo/bar.log
                    <br />
                    &nbsp;&nbsp;pos_file /var/log/td-agent/foo-bar.log.pos
                    <br />
                    &nbsp;&nbsp;tag foo.bar
                    <div>
                      &nbsp;&nbsp;format /{this.props.regexp}/
                    </div>
                    {time_format_template}
                    &lt;/source&gt;
                  </div>
                </section>
              </div>
            );
          }
        });

        var TimeFormatTemplate = React.createClass({
          render: function() {
            return <div>&nbsp;&nbsp;time_format {this.props.time_format}</div>;
          }
        });

        React.render(
          <FluentularApp />,
          document.getElementById('app')
        );
    :css
      @import url(http://fonts.googleapis.com/css?family=Squada+One);
      body {
        border-top: 7px solid #2795b6;
        padding-top: 10px;
      }
      h1 {
        font-family: 'Squada One', cursive, sans-serif;
      }
      h3 {
        margin: 40px 0px 20px;
        border-bottom: 1px solid #eee;
      }
      img.github {
        position: absolute;
        top: 0;
        right: 0;
        border: 0;
      }
      i.fa-heart {
        color: #ff79c6;
      }
  %body
    %a(href='https://github.com/Tomohiro/fluentular')
      %img.github(src='http://s3.amazonaws.com/github/ribbons/forkme_right_red_aa0000.png' alt='Fork me on GitHub')

    %header.row.small-centered.columns
      %section
        %h1
          %a(href='/') Fluentular
          %img(src='https://img.shields.io/badge/fluentd-v#{Fluent::VERSION}-orange.svg?style=flat-square')
        %h4 a Fluentd regular expression editor

    %article#app

    %div.row
      %section.small-12.small-centered.columns
        %h3
          %i.fa.fa-crosshairs
          Data Inspector
        %h4 Attributes
        %table.small-12
          %thead
            %tr
              %th.small-4 Key
              %th.small-8 Value
          %tbody
            - if @parsed
              %tr
                %th.small-4 time
                %td.small-8 #{Time.at(@parsed_time).strftime("%Y/%m/%d %H:%M:%S %z")}
            - else
              %tr
                %th.small-4
                %td.small-12
        %h4 Records
        %table.small-12
          %thead
            %tr
              %th.small-4 Key
              %th.small-8 Value
          %tbody
            - if @parsed
              - @parsed.each do |key, value|
                %tr
                  %th&= key
                  %td&= value
            - else
              %tr
                %th
                %td

    %footer.row.small-centered.columns
      %section.small-12.medium-5.columns
        %p
          &copy; 2012 - 2015 Made with
          %i.fa.fa-heart
          by
          %a(href='https://github.com/Tomohiro') Tomohiro TAIRA
      %section.small-12.medium-4.columns.medium-offset-3
        %p
          Powered by
          %a(href='http://www.sinatrarb.com/') Sinatra
          Hosted on
          %a(href='http://heroku.com') Heroku
