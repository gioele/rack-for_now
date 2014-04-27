require 'rack/builder'

module Rack::ForNow
	class FakeService
		def method_missing(m, *args, &block)
			return nil
		end
	end

	class Service
		def subpath
			return @subpath || default_subpath
		end
		attr_writer :subpath

		def parent_service
			return @parent_service || FakeService.new
		end
		attr_writer :parent_service

		attr_reader :template_url

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

		def call(env)
			@app ||= app
			@app.call(env)
		end

		def with(*subservices)
			subservices.each do |subservice|
				subservice = subservice.new if subservice.is_a? Class

				subservice.parent_service = self

				@subservices ||= {}
				@subservices[subservice.subpath] = subservice
			end

			return self
		end

		def self.on(path)
			service = self.new
			service.subpath = path

			return service
		end

		def last_URL_segment(env)
			path = env['SCRIPT_NAME'].to_s + env['PATH_NAME'].to_s
			segments = path.split('/')

			idx_last = (segments.last == subpath) ? -2 : -1
			return segments[idx_last]
		end

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
