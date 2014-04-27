require 'rack/test'

require 'rack/for_now'

APP = Rack::Builder.new do
	map '/othello' do
		run Rack::ForNow::GitHub.new('will')
	end

	map '/iago' do
		run Rack::ForNow::GitHub.new('will', 'othello')
	end

	map '/romeo' do
		run Rack::ForNow::GitHub.new('will').
		    with(Rack::ForNow::GHIssues, Rack::ForNow::GHPages).
		    with(Rack::ForNow::RubyDoc.on('documentation'))
	end

	map '/juliet' do
		run Rack::ForNow::GitHub.new('will', 'romeo').
		    with(Rack::ForNow::RubyDoc)
	end

	map '/venice' do
		run Rack::ForNow::RubyDoc.new
	end

	map '/' do
		run Proc.new { |env| [200, { 'Content-Type' => 'text/plain' }, ["Default page"]] }
	end
end.to_app

describe Rack::ForNow do
	include Rack::Test::Methods

	let(:app) { APP }

	it "des not interfere with normal paths" do
		get '/'

		last_response.should be_ok
		last_response.body.should == 'Default page'
	end

	it "redirects to GitHub" do
		get '/iago'

		last_response.status.should == 307
		last_response.header['Location'].should == 'https://github.com/will/othello'
	end

	it "redirects to Rubydoc.info" do
		get '/venice'

		last_response.status.should == 307
		last_response.header['Location'].should == 'http://rubydoc.info/gems/venice'
	end

	it "redirects to GitHub Pages" do
		get '/romeo/docs'

		last_response.status.should == 307
		last_response.header['Location'].should == 'http://will.github.io/romeo'
	end

	it "redirects when the path ends with a slash" do
		get '/venice/'

		last_response.status.should == 307
		last_response.header['Location'].should == 'http://rubydoc.info/gems/venice'
	end

	it "deduces the project's name from the path" do
		get '/othello'

		last_response.status.should == 307
		last_response.header['Location'].should == 'https://github.com/will/othello'
	end

	it "allows composition with other services" do
		get '/juliet/docs'

		last_response.status.should == 307
		last_response.header['Location'].should == 'http://rubydoc.info/gems/romeo'
	end

	it "allows composition with other services with arbitrary subpaths" do
		get '/romeo/documentation'

		last_response.status.should == 307
		last_response.header['Location'].should == 'http://rubydoc.info/gems/romeo'
	end

	it "returns 404 for unknown subpaths" do
		get '/juliet/others'

		last_response.status.should == 404
	end
end

# This is free software released into the public domain (CC0 license).
