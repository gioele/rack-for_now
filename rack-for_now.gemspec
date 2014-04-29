# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
	spec.name          = 'rack-for_now'
	spec.version       = '0.2.dev'
	spec.authors       = ["Gioele Barabucci"]
	spec.email         = ["gioele@svario.it"]
	spec.summary       = %q{Use third-party services, publish your domain URL}
	spec.description   = %q{rack-for_now is a Rack middleware component that } +
	                     %q{redirects project URLs to GitHub, Rubygems and } +
	                     %q{other online service. It allows you to use your } +
	                     %q{domain as the permanent URL of your project while } +
	                     %q{still using these handy 3rd-party services.}

	spec.homepage      = 'http://svario.it/rack-for_now'
	spec.license       = 'CC0'

	spec.files         = `git ls-files`.split($/)
	spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
	spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
	spec.require_paths = ['lib']

	spec.add_dependency 'rack'

	spec.add_development_dependency 'bundler', '~> 1.3'
	spec.add_development_dependency 'rack-test'
	spec.add_development_dependency 'rake'
	spec.add_development_dependency 'rspec'
end

# This is free software released into the public domain (CC0 license).
