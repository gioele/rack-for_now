require 'rack/test'
begin; require 'coco'; rescue LoadError; warn "Couldn't load COCO; code coverage not available."; end

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

	map '/midnight' do
		run Rack::ForNow::GitHub.new('will').
			with(Rack::ForNow::RubyDocGitHub)
	end

	map '/capuleti' do
		run Rack::ForNow::MavenCentral.new('uk.shakespeare.william', 'romeo')
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

	it "redirects to Rubydoc.info for GitHub repos" do
		get '/midnight/docs'

		last_response.status.should == 307
		last_response.header['Location'].should == 'http://rubydoc.info/github/will/midnight'
	end

	it "redirects to GitHub Pages" do
		get '/romeo/docs'

		last_response.status.should == 307
		last_response.header['Location'].should == 'http://will.github.io/romeo'
	end

	it "redirects to GitHub Issues" do
		get '/romeo/issues'

		last_response.status.should == 307
		last_response.header['Location'].should == 'https://github.com/will/romeo/issues'
	end

	it "redirects to MavenCentral" do
		get '/capuleti'

		last_response.status.should == 307
		last_response.header['Location']. should == 'http://search.maven.org/#search|ga|1|g%3A%22uk.shakespeare.william%22%20AND%20a%3A%22romeo%22'
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

	it "raises an exception if a template has an unbound variable" do
		Rack::ForNow::MavenCentral.send(:remove_const, :TEMPLATE_URL)
		Rack::ForNow::MavenCentral.const_set(:TEMPLATE_URL, 'http://example.org/%{project}/%{other_info}')
		expect { get '/capuleti' }.to raise_exception
	end
end

# This is free software released into the public domain (CC0 license).
