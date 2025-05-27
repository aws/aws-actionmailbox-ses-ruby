# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

gem 'rake', require: false

case ENV.fetch('RAILS_VERSION', nil)
when '7.1'
  gem 'activerecord-jdbc-adapter', '~> 71.0', platform: :jruby
  gem 'activerecord-jdbcsqlite3-adapter', '~> 71.0', platform: :jruby
  gem 'rails', '~> 7.1.0'
when '7.2'
  gem 'rails', '~> 7.2.0'
when '8.0'
  gem 'rails', '~> 8.0.0'
else
  gem 'rails', github: 'rails/rails'
end

case RUBY_VERSION
when /2.7.\d+/
  gem 'sqlite3', '~> 1.6.0', platform: :ruby
when /3.0.\d+/
  gem 'sqlite3', '~> 1.7.0', platform: :ruby
else
  gem 'sqlite3', platform: :ruby
end

group :development do
  gem 'byebug', platforms: :ruby
  gem 'rubocop'
end

group :test do
  gem 'rspec-rails'
  gem 'webmock'
end

group :docs do
  gem 'yard'
  gem 'yard-sitemap', '~> 1.0'
end

group :release do
  gem 'octokit'
end
