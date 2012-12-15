# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cassava/version'

Gem::Specification.new do |gem|
  gem.name          = "cassava"
  gem.version       = Cassava::VERSION
  gem.authors       = ["Kurt Stephens"]
  gem.email         = ["ks.github@kurtstephens.com"]
  gem.description   = %q{A command-line CSV tool.}
  gem.summary       = %q{A command-line CSV tool.}
  gem.homepage      = "https://github.com/kstephens/cassava"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_dependency 'terminal-table', '~> 1.4.5'

  gem.add_development_dependency "rake", "~> 10.0.2"
  gem.add_development_dependency "rspec", "~> 2.12.0"
end
