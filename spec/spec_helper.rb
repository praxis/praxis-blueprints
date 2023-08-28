# frozen_string_literal: true

require 'coveralls'
Coveralls.wear!

Encoding.default_external = Encoding::UTF_8

require 'rubygems'
require 'bundler/setup'

# Configure simplecov gem (must be here at top of file)
# require 'simplecov'
# SimpleCov.start do
#  add_filter 'spec' # Don't include RSpec stuff
# end

# $LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
# $LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift 'lib'

Bundler.setup(:default, :development, :test)
Bundler.require(:default, :development, :test)

require 'praxis-blueprints'

require_relative 'support/spec_blueprints'

RSpec.configure do |config|
  config.backtrace_exclusion_patterns = [
    %r{/lib/\d*/ruby/},
    %r{bin/},
    /gems/,
    %r{spec/spec_helper.rb},
    %r{lib/rspec/(core|expectations|matchers|mocks)},
    %r{org/jruby/.*.java}
  ]

  config.before(:suite) do
    Praxis::Blueprint.finalize!
  end
end
