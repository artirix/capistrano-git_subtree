# -*- encoding: utf-8 -*-
require File.expand_path('../lib/capistrano-git_subtree/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Barnaby Gray"]
  gem.email         = ["barnaby.gray@artirix.com"]
  gem.description   = %q{Capistrano extension to deploy from a git subdirectory}
  gem.summary       = %q{Capistrano extension to deploy from a git subdirectory}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "capistrano-git_subtree"
  gem.require_paths = ["lib"]
  gem.version       = Capistrano::GitSubtree::VERSION
end
