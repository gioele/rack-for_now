require 'rack/builder'

module Rack::ForNow

	# The `Service` class is the base classes for all the
	# third-party services made available by `Rack::ForNow`.
	#
	# @abstract The `Service` class is not meant to be used directly.

	class Service
		# @return [String] the default path where the service will be mounted.

		def default_subpath
			self.class.const_get(:DEFAULT_SUBPATH)
		end

		# @return [String] the template URL for the service.

		def template_url
			self.class.const_get(:TEMPLATE_URL)
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
		def call(env)
			@app ||= app
			@app.call(env)
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
		def main_app
			lambda do |env|
				root_requested = env['PATH_INFO'].chomp('/').empty?
				if !root_requested
					return [404, {'Content-Type' => 'text/plain', 'X-Cascade' => 'pass'}, ["Not Found: #{env['PATH_INFO']}"]]
				end

				set_parameters
				infer_runtime_parameters(env)

				destination_url = personalized(template_url)

				return [307, { 'Location' => destination_url }, [""]]
			end
		end

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

		# Set the service parameters, inheriting from the parent service if needed.
		#
		# @api private
		#
		# @return void

		def set_parameters
			if parent_service.nil?
				return
			end

			params = self.instance_variables.map(&:to_sym)
			params -= [:@app, :@parent_service, :@subpath, :@subservices]
			params.reject! { |param_name| !self.instance_variable_get(param_name).nil? }

			methods = params.map { |param_name| param_name.to_s[1..-1].to_sym }

			params.each_with_index do |param_name, idx|
				value = parent_service.send(methods[idx])
				self.instance_variable_set(param_name, value)
			end
		end

		# Infer parameters from the Rack request.
		#
		# @api private
		#
		# @return void

		def infer_runtime_parameters(env)
			# TODO: provide a way to update also other parameters
			params = self.instance_variables.map(&:to_sym)
			if params.include?(:@project)
				@project ||= last_URL_segment(env)
			end
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
		DEFAULT_SUBPATH = 'code'
		TEMPLATE_URL = 'https://github.com/%{user_name}/%{project}'

		def initialize(user_name = nil, project = nil)
			@user_name = user_name
			@project = project
		end

		attr_reader :user_name
		attr_reader :project
	end

	class GHIssues < GitHub
		DEFAULT_SUBPATH = 'issues'
		TEMPLATE_URL = 'https://github.com/%{user_name}/%{project}/issues'
	end

	class GHPages < GitHub
		DEFAULT_SUBPATH = 'docs'
		TEMPLATE_URL = 'http://%{user_name}.github.io/%{project}'
	end

	class RubyDoc < Service
		DEFAULT_SUBPATH = 'docs'
		TEMPLATE_URL = 'http://rubydoc.info/gems/%{project}'

		def initialize(project = nil)
			@project = project
		end

		attr_reader :project
	end

	class MavenCentral < Service
		DEFAULT_SUBPATH = 'maven'
		TEMPLATE_URL = 'http://search.maven.org/#search|ga|1|g%3A%22%{group_id}%22%20AND%20a%3A%22%{project}%22'

		def initialize(group_id, project = nil)
			@group_id = group_id
			@project = project
		end

		attr_reader :group_id
		attr_reader :project
	end
end

# This is free software released into the public domain (CC0 license).
