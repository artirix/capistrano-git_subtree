# Capistrano::GitSubtree

Capistrano extension to deploy from a git subdirectory.

## Installation

Add this line to your application's Gemfile:

    gem 'capistrano-git_subtree'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install capistrano-git_subtree

## Usage

In your config/deploy.rb:

	require 'capistrano-git_subtree'

	set :scm, :git_subtree
	set :git_subtree, "path/to/my/application"

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
