require 'rack/builder'

module Rack::ForNow

	# The `Service` class is the base classes for all the
	# third-party services made available by `Rack::ForNow`.
	#
	# @abstract The `Service` class is not meant to be used directly.

	class Service
		# @api private
		def subpath
			return @subpath || default_subpath
		end
		attr_writer :subpath

		# @api private
		def parent_service
			return @parent_service || FakeService.new
		end
		attr_writer :parent_service

		# @api private
		def main_app
			lambda do |env|
				root_requested = env['PATH_INFO'].chomp('/').empty?
				if !root_requested
					return [404, {'Content-Type' => 'text/plain', 'X-Cascade' => 'pass'}, ["Not Found: #{env['PATH_INFO']}"]]
				end

				update_context_values(env)

				destination_url = personalized(template_url)

				return [307, { 'Location' => destination_url }, [""]]
			end
		end

		# @api private
		def app
			builder = Rack::Builder.new

			@subservices ||= {}
			@subservices.each do |path, service|
				builder.map('/' + path) { run service.main_app }
			end

			service = self
			builder.map('/') { run service.main_app }

			return builder.to_app
		end

		# @api private
		def call(env)
			@app ||= app
			@app.call(env)
		end

		# Mounts a service on a subpath.
		#
		# @example Mount a GitHub Issues redirect under `/romeo/issues` (default path)
		#
		#     map '/romeo' do
		#         run Rack::ForNow::GitHub.new('will').with(Rack::ForNow::GHIssues)
		#     end
		#
		# @example Mount a GitHub Issues redirect under `/romeo/bugs`
		#
		#     map '/romeo' do
		#         run Rack::ForNow::GitHub.new('will').with(Rack::ForNow::GHIssues.on('bugs'))
		#     end
		#
		# @example Mount multiple services
		#
		#     map '/romeo' do
		#         run Rack::ForNow::GitHub.new('will').
		#             with(Rack::ForNow::GHIssues, Rack::ForNow::Rubydoc).
		#             with(Rack::ForNow::GHPages.on('tutorial')).
		#     end
		#
		# @see .on
		#
		# @api public
		#
		# @param [Service, Class] subservices the services to mount
		#
		# @return [Service] the service itself

		def with(*subservices)
			subservices.each do |subservice|
				subservice = subservice.new if subservice.is_a? Class

				subservice.parent_service = self

				@subservices ||= {}
				@subservices[subservice.subpath] = subservice
			end

			return self
		end

		# Sets up a service to be installed on an arbitrary path
		#
		# @example
		#
		#     map '/romeo' do
		#         run Rack::ForNow::GitHub.new('will').
		#               with(Rack::ForNow::Rubydoc). # this sets up `/romeo/docs`
		#               with(Rack::ForNow::Rubydoc.on('/documentation') # this sets up `/romeo/documentation`
		#     end
		#
		# @see #with
		#
		# @api public
		#
		# @param [String] path the path under which the service is to be installed
		#
		# @return [Service] the service, set up so to be installed on `path`

		def self.on(path)
			service = self.new
			service.subpath = path

			return service
		end

		# @api private
		def last_URL_segment(env)
			path = env['SCRIPT_NAME'].to_s + env['PATH_NAME'].to_s
			segments = path.split('/')

			idx_last = (segments.last == subpath) ? -2 : -1
			return segments[idx_last]
		end

		# @api private
		def personalized(url_template)
			placeholders = url_template.scan(/\%\{(.*?)\}/).to_a.flatten.uniq
			values = Hash[placeholders.map { |placeholder| [placeholder, instance_variable_get("@#{placeholder}".to_sym)] }]

			values.each do |placeholder, value|
				if value.nil?
					raise "Unset template variable #{placeholder} for #{self.class}"
				end
			end

			url = url_template
			values.each do |placeholder, value|
				url = url.gsub("%{#{placeholder}}", value)
			end

			return url
		end
	end

	# @private
	class FakeService
		def method_missing(m, *args, &block)
			return nil
		end
	end

	class GitHub < Service
		def default_subpath; 'code'; end
		def template_url; 'https://github.com/%{user_name}/%{project}'; end

		def initialize(user_name = nil, project = nil)
			@user_name = user_name
			@project = project
		end

		attr_reader :user_name
		attr_reader :project

		def update_context_values(env)
			@project ||= parent_service.project unless parent_service.nil?
			@user_name ||= parent_service.user_name unless parent_service.nil?

			@project ||= last_URL_segment(env)
		end
	end

	class GHIssues < GitHub
		def default_subpath; 'issues'; end
		def template_url; 'https://github.com/%{user_name}/%{project}/issues'; end
	end

	class GHPages < GitHub
		def default_subpath; 'docs'; end
		def template_url; 'http://%{user_name}.github.io/%{project}'; end
	end

	class RubyDoc < Service
		def default_subpath; 'docs'; end
		def template_url; 'http://rubydoc.info/gems/%{project}'; end

		def initialize(project = nil)
			@project = project
		end

		def update_context_values(env)
			@project ||= parent_service.project unless parent_service.nil?

			@project ||= last_URL_segment(env)
		end
	end
end

# This is free software released into the public domain (CC0 license).
