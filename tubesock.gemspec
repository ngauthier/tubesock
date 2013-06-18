# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'tubesock/version'

Gem::Specification.new do |spec|
  spec.name          = "tubesock"
  spec.version       = Tubesock::VERSION
  spec.authors       = ["Nick Gauthier"]
  spec.email         = ["ngauthier@gmail.com"]
  spec.description   = %q{Websocket interface on Rack Hijack w/ Rails support}
  spec.summary       = %q{Handle websocket connections via Rack and Rails 4 using concurrency}
  spec.homepage      = "http://github.com/ngauthier/tubesock"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "rack", ">= 1.5.0"
  spec.add_dependency "websocket", ">= 1.1.0"

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "minitest", "~> 4.7.3"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "activesupport"
end
