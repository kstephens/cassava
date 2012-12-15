require "bundler/gem_tasks"
gem 'rspec'
require 'rspec/core/rake_task'

desc "Default => :test"
task :default => :test

desc "Run all tests"
task :test => [ :spec ]

desc "Run specs"
RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = "./spec/**/*_spec.rb" # don't need this, it's default.
  # Put spec opts in a file named .rspec in root
end

