`rack-for_now`: use third-party services, publish your domain URL
=================================================================

> Yeah, this project will be a great success, I will need to set up
> my own git server. And an issue tracker. And a full data center
> to run it!
>
> Well, _for now_ GitHub will do.

`rack-for_now` is a Rack middleware component that redirects project
URLs to GitHub, Rubygems and other online service. It allows you to use your
domain as the permanent URL of your project while still using these handy
third-party services.


Examples
--------

The most basic way to use `rack-for_now` is to mount it in `config.ru`
or with `Rack::Builder`.

    # let's create a redirect from `/othello` to GitHub, under
    # the user `will`
    map '/othello' do
        run Rack::ForNow::GitHub.new('will', 'othello')
    end

It is possible to omit the project name if it is the same as the
URL where `rack-for_now` is mounted.

    # Rack::ForNow::GitHub will understand that the project name is `othello`
    map '/othello' do
        run Rack::ForNow::GitHub.new('will')
    end

A more interesting use is to add additional subpaths for other
services using the `#with(*subservices)` method.

    # this will redirect
    # * `/romeo` to <https://github.com/will/romeo>,
    # * `/romeo/docs` to <http://rubydoc.info/gems/romeo>,
    # * `/romeo/issues` to <https://github.com/will/issues>
    map '/romeo' do
        run Rack::ForNow::GitHub.new('will').
	    with(Rack::ForNow::GHIssues,
	         Rack::ForNow::RubyDoc)
    end

The services have their default mount point, for example `RubyDoc` will
automatically be mounted on `./docs`. It is possible to configure under
which path they are mounted on using `.on(mount_point)`.

    # redirect to rubydocs.info when `/romeo/api-docs` is requested
    map '/romeo' do
        run Rack::ForNOw::GitHub.new('will').
	    with(Rack::ForNow::RubyDoc.on('api-docs'))
    end


Requirements
------------

`rack-for_now` requires a recent Rack but does not depend on any
other gem.


Install
-------

    gem install rack-for_now


Author
------

* Gioele Barabucci <http://svario.it/gioele> (initial author)


Development
-----------

Code
: <https://svario.it/rack-for_now>

Report issues
: <https://svario.it/rack-for_now/issues>

Documentation
: <https://svario.it/rack-for_now/docs>


License
-------

This is free software released into the public domain (CC0 license).

See the `COPYING.CC0` file or <http://creativecommons.org/publicdomain/zero/1.0/>
for more details.
