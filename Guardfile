# frozen_string_literal: true

# Config file for Guard
# More info at https://github.com/guard/guard#readme
group :red_green_refactor, halt_on_fail: true do
  guard :rspec, cmd: 'bundle exec rspec' do
    watch(%r{^spec/.+_spec\.rb$})
    watch(%r{^lib/praxis-blueprints/(.+)\.rb$}) { |m| "spec/praxis-blueprints/#{m[1]}_spec.rb" }
    watch('spec/*.rb') { 'spec' }
    watch('lib/praxis-blueprints.rb') { 'spec' }
    watch(%r{^spec/support/(.+)\.rb$}) { 'spec' }
  end

  guard :rubocop, cli: '--auto-correct --display-cop-names' do
    watch(/.+\.rb$/)
    watch(%r{(?:.+/)?\.rubocop\.yml$}) { |m| File.dirname(m[0]) }
  end
end
