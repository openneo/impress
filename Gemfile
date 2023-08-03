source 'http://rubygems.org'
ruby '2.6.10'

gem 'rails', '= 6.1.7.4'

# Our database is MySQL, in both development and production.
gem 'mysql2', '~> 0.5.5'

# For reading the .env file, which you can use in development to more easily
# set environment variables for secret data.
gem 'dotenv-rails', '~> 2.8', '>= 2.8.1'

# For the asset pipeline: templates, CSS, JS, etc.
gem 'haml', '~> 6.1', '>= 6.1.1'
gem 'sass-rails', '~> 5.0', '>= 5.0.7'
gem 'compass-rails', '~> 3.1'
gem 'uglifier', '~> 4.2'
gem 'react-rails', '~> 2.7', '>= 2.7.1'

# For authentication.
gem 'devise', '~> 4.9', '>= 4.9.2'

# For pagination UI.
gem 'will_paginate', '~> 4.0'

# For translation, both for the site UI and for Neopets data.
gem 'rails-i18n', '~> 7.0', '>= 7.0.7'
gem 'http_accept_language', '~> 2.1', '>= 2.1.1'
gem 'globalize', '~> 6.2', '>= 6.2.1'

# For reading and parsing HTML from Neopets.com, like importing Closet pages.
gem 'nokogiri', '~> 1.13', '>= 1.13.10'
gem 'rest-client', '~> 2.1'

# For safely rendering users' Markdown + HTML on item list pages.
gem 'rdiscount', '~> 2.2', '>= 2.2.7.1'
gem 'sanitize', '~> 6.0', '>= 6.0.2'

# For working with Neopets APIs.
# unstable version of RocketAMF interprets info registry as a hash instead of an array
gem 'RocketAMF', :git => 'https://github.com/rubyamf/rocketamf.git'

# For working with the OpenNeo ID service.
gem 'msgpack', '~> 1.7', '>= 1.7.2'
gem 'openneo-auth-signatory', '~> 0.1.0'

# For preventing too many modeling attempts.
gem 'rack-attack', '~> 6.7'

# For testing emails in development.
gem 'letter_opener', '~> 1.8', '>= 1.8.1', group: :development

# For parallel API calls.
gem 'parallel', '~> 1.23'

# For debugging.
gem 'web-console', '~> 4.2', group: :development

# TODO: Review our use of content_tag_for etc and uninstall this!
gem 'record_tag_helper', '~> 1.0', '>= 1.0.1'

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', '~> 1.16', require: false

# For deployment.
group :development do
  gem 'capistrano', '~> 2.15.5', require: false
  gem 'rvm-capistrano', '~> 1.5.6', require: false
end

# For production caching.
group :production do
  gem 'memcache-client', '~> 1.8.5', :require => 'memcache'
end

# For testing.
group :test do
  gem 'factory_girl_rails', '~> 4.9'
  gem 'rspec-rails', '~> 2.0.0.beta.22'
end
