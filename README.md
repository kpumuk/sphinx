# Sphinx Client API

[![Travis-CI build status](https://secure.travis-ci.org/kpumuk/sphinx.png)](http://travis-ci.org/kpumuk/sphinx)

This document gives an overview of what is Sphinx itself and how to use it
from your Ruby on Rails application. For more information about Sphinx and
its API documentation visit [sphinxsearch.com](http://www.sphinxsearch.com).

## Sphinx

Sphinx is a standalone full-text search engine, meant to provide fast,
size-efficient and relevant fulltext search functions to other applications.
Sphinx was specially designed to integrate well with SQL databases and
scripting languages. Currently built-in data sources support fetching data
either via direct connection to MySQL, or from an XML pipe.

Simplest way to communicate with Sphinx is to use `searchd` —
a daemon to search through full text indexes from external software.

## Installation

Add the "sphinx" gem to your `Gemfile`.

    gem 'sphinx'

And run `bundle install` command.

## Documentation

Complete Sphinx plugin documentation could be found on [GitHub Pages](http://kpumuk.github.com/sphinx).

Also you can find documentation on [rdoc.info](http://rdoc.info/projects/kpumuk/sphinx).

You can build the documentation locally by running:

    rake yard

Complete Sphinx API documentation could be found on [Sphinx Search Engine
site](http://www.sphinxsearch.com/docs/current.html).
This plugin is fully compatible with original PHP API implementation.

## Ruby naming conventions

Sphinx Client API supports Ruby naming conventions, so every API
method name is in underscored, lowercase form:

    SetServer    -> set_server
    RunQueries   -> run_queries
    SetMatchMode -> set_match_mode

Every method is aliased to a corresponding one from standard Sphinx
API, so you can use both `SetServer` and `set_server`
with no differrence.

There are three exceptions to this naming rule:

    GetLastError   -> last_error
    GetLastWarning -> last_warning
    IsConnectError -> connect_error?

Of course, all of them are aliased to the original method names.

## Using multiple Sphinx servers

Since we actively use this plugin in our Scribd development workflow,
there are several methods have been added to accommodate our needs.
You can find documentation on Ruby-specific methods in [documentation](http://rdoc.info/projects/kpumuk/sphinx).

First of all, we added support of multiple Sphinx servers to balance
load between them. Also it means that in case of any problems with one
of servers, library will try to fetch the results from another one.
Every consequence request will be executed on the next server in list
(round-robin technique).

    sphinx.set_servers([
      { :host => 'browse01.local', :port => 3312 },
      { :host => 'browse02.local', :port => 3312 },
      { :host => 'browse03.local', :port => 3312 }
    ])

By default library will try to fetch results from a single server, and
fail if it does not respond. To setup number of retries being performed,
you can use second (additional) parameter of the `set_connect_timeout`
and `set_request_timeout` methods:

    sphinx.set_connect_timeout(1, 3)
    sphinx.set_request_timeout(1, 3)

There is a big difference between these two methods. First will affect
only on requests experiencing problems with connection (socket error,
pipe error, etc), second will be used when request is broken somehow
(temporary searchd error, incomplete reply, etc). The workflow looks like
this:

1. Increase retries number. If is less or equal to configured value,
   try to connect to the next server. Otherwise, raise an error.
2. In case of connection problem go to 1.
3. Increase request retries number. If it less or equal to configured
   value, try to perform request. Otherwise, raise an error.
4. In case of connection problem go to 1.
5. In case of request problem, go to 3.
6. Parse and return response.

Withdrawals:

1. Request could be performed `connect_retries` * `request_retries`
   times. E.g., it could be tried `request_retries` times on each
   of `connect_retries` servers (when you have 1 server configured,
   but `connect_retries` is 5, library will try to connect to this
   server 5 times).
2. Request could be tried to execute on each server `1..request_retries`
   times. In case of connection problem, request will be moved to another
   server immediately.

Usually you will set `connect_retries` equal to servers number,
so you will be sure each failing request will be performed on all servers.
This means that if one of servers is live, but others are dead, you request
will be finally executed successfully.

## Sphinx constants

Most Sphinx API methods expecting for special constants will be passed.
For example:

    sphinx.set_match_mode(Sphinx::SPH_MATCH_ANY)

Please note that these constants defined in a `Sphinx`
module. You can use symbols or strings instead of these awful
constants:

    sphinx.set_match_mode(:any)
    sphinx.set_match_mode('any')

## Setting query filters

Every `set_` method returns `Sphinx::Client` object itself.
It means that you can chain filtering methods:

    results = Sphinx::Client.new.
                set_match_mode(:any).
                set_ranking_mode(:bm25).
                set_id_range(10, 1000).
                query('test')

There is a handful ability to set query parameters directly in `query`
call. If block does not accept any parameters, it will be eval'ed inside
Sphinx::Client instance:

    results = Sphinx::Client.new.query('test') do
      match_mode :any
      ranking_mode :bm25
      id_range 10, 1000
    end

As you can see, in this case you can omit the `set_` prefix for
this methods. If block accepts a parameter, sphinx instance will be
passed into the block. In this case you should you full method names
including the `set_` prefix:

    results = Sphinx::Client.new.query('test') do |sphinx|
      sphinx.set_match_mode :any
      sphinx.set_ranking_mode :bm25
      sphinx.set_id_range 10, 1000
    end

## Example

This simple example illustrates base connection establishing,
search results retrieving, and excerpts building. Please note
how does it perform database select using ActiveRecord to
save the order of records established by Sphinx.

    sphinx = Sphinx::Client.new
    result = sphinx.query('test')
    ids = result['matches'].map { |match| match['id'] }
    posts = Post.all :conditions => { :id => ids },
                     :order => "FIELD(id,#{ids.join(',')})"

    docs = posts.map(&:body)
    excerpts = sphinx.build_excerpts(docs, 'index', 'test')

## Logging

You can ask Sphinx client API to log it's activity to some log. In
order to do that you can pass a logger object into the `Sphinx::Client`
constructor:

    require 'logger'
    Sphinx::Client.new(Logger.new(STDOUT)).query('test')

Logger object should respond to methods :debug, :info, and :warn, and
accept blocks (this is what standard Ruby `Logger` class does).
Here is what you will see in your log:

* `DEBUG` -- `query`, `add_query`, `run_queries`
  method calls with configured filters.
* `INFO` -- initialization with Sphinx version, servers change,
  attempts to re-connect, and all attempts to do an API call with server
  where request being performed.
* `WARN` -- various connection and socket errors.

## Support

You can find source code for this library on [GitHub](http://github.com/kpumuk/sphinx).

To suggest a feature or report a bug use [GitHub Issues](http://github.com/kpumuk/sphinx/issues)

## Credits

* [Dmytro Shteflyuk](https://github.com/kpumuk) (author)
* [Andrew Aksyonoff](http://sphinxsearch.com) (Sphinx core developer)

Special thanks to [Alexey Kovyrin](https://github.com/kovyrin)

Special thanks to [Mike Perham](https://github.com/mperham) for his awesome
memcache-client gem, where latest Sphinx gem got new sockets handling from.

## License

This library is distributed under the terms of the Ruby license.
You can freely distribute/modify this library.
