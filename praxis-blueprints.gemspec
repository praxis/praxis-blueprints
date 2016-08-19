# frozen_string_literal: true
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'praxis-blueprints/version'

Gem::Specification.new do |spec|
  spec.name          = 'praxis-blueprints'
  spec.version       = Praxis::BLUEPRINTS_VERSION
  spec.authors = ['Josep M. Blanquer', 'Dane Jensen']
  spec.summary = 'Attributes, views, rendering and example generation for common Blueprint Structures.'
  spec.description = <<-EOF
    Praxis Blueprints is a library that allows for defining a reusable class
    structures that has a set of typed attributes and a set of views with which
    to render them. Instantiations of Blueprints resemble ruby Structs which
    respond to methods of the attribute names. Rendering is format-agnostic in
    that it results in a structured hash instead of an encoded string.
    Blueprints can automatically generate object structures that follow the
    attribute definitions.
  EOF
  spec.email = ['blanquer@gmail.com', 'dane.jensen@gmail.com']

  spec.homepage = 'https://github.com/rightscale/praxis-blueprints'
  spec.license = 'MIT'
  spec.required_ruby_version = '>=2.1'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_runtime_dependency('randexp', ['~> 0'])
  spec.add_runtime_dependency('attributor', ['>= 5.1'])
  spec.add_runtime_dependency('activesupport', ['>= 3'])

  spec.add_development_dependency 'bundler', '~> 1.6'
  spec.add_development_dependency 'rake', '~> 0'

  spec.add_development_dependency('redcarpet', ['< 3.0'])
  spec.add_development_dependency('yard', ['~> 0.8.7'])
  spec.add_development_dependency('guard', ['~> 2'])
  spec.add_development_dependency('guard-rspec', ['>= 0'])
  spec.add_development_dependency('rspec', ['< 2.99'])
  spec.add_development_dependency('pry', ['~> 0'])
  spec.add_development_dependency('pry-byebug', ['~> 1'])
  spec.add_development_dependency('pry-stack_explorer', ['~> 0'])
  spec.add_development_dependency('fuubar', ['~> 1'])
  spec.add_development_dependency('coveralls')
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'guard-rubocop'
end
