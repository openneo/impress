source 'http://rubygems.org'
ruby '2.4.10'

gem 'rails', '= 4.2.11.3'

# Our database is MySQL, in both development and production.
gem 'mysql2', '>= 0.3.11'

# For reading the .env file, which you can use in development to more easily
# set environment variables for secret data.
gem 'dotenv-rails', '~> 2.8', '>= 2.8.1'

# For the asset pipeline: templates, CSS, JS, etc.
gem 'haml', '~> 6.1', '>= 6.1.1'
gem 'sass-rails', '~> 5.0', '>= 5.0.7'
gem 'compass-rails', '~> 3.1'
gem 'uglifier', '~> 4.2'
gem 'react-rails', '~> 2.7', '>= 2.7.1'

# For UI libraries.
gem 'will_paginate', '~> 3.0.pre2'

# For authentication.
gem 'devise', '~> 4.9', '>= 4.9.2'

# For translation, both for the site UI and for Neopets data.
gem 'rails-i18n', '~> 4.0', '>= 4.0.9'
gem 'http_accept_language', '~> 2.1', '>= 2.1.1'
gem 'globalize', '~> 4.0.3'

# For reading and parsing HTML from Neopets.com, like importing Closet pages.
gem 'nokogiri', '~> 1.10', '>= 1.10.10'
gem "rest-client", "~> 1.6.7"

# For safely rendering users' Markdown + HTML on item list pages.
gem 'rdiscount', '~> 1.6.5'
gem 'sanitize', '~> 2.0.3'

# For working with Neopets APIs.
# unstable version of RocketAMF interprets info registry as a hash instead of an array
gem 'RocketAMF', :git => 'https://github.com/rubyamf/rocketamf.git'

# For working with the OpenNeo ID service.
gem 'msgpack', '~> 1.6', '>= 1.6.1'
gem 'openneo-auth-signatory', '~> 0.1.0'

# For preventing too many modeling attempts.
gem 'rack-attack', '~> 2.2.0'

# For testing emails in development.
gem "letter_opener", :group => :development

# For parallel API calls.
gem "parallel", "~> 1.13.0"

# For debugging.
gem 'web-console', '~> 2.2', '>= 2.2.1'

# TODO: Rails requests the latest version of these dependencies, but they
# require Ruby 2.5 or higher, so we have to request lower ones instead!
# (loofah is slightly trickier: it requires a recent nokogiri, but recent
# nokogiri requires Ruby 2.6, so, yeah.)
gem 'loofah', '~> 2.20', '< 2.21'
gem 'minitest', '~> 5.15', '< 5.16'
gem 'mail', '~> 2.7', '>= 2.7.1', '< 2.8'

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
