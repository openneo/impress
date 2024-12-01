source 'https://rubygems.org'
ruby '3.3.5'

gem 'rails', '~> 7.2', '>= 7.2.1'

# The HTTP server running the Rails instance.
gem 'falcon', '~> 0.48.0'

# Our database is MySQL, in both development and production.
gem 'mysql2', '~> 0.5.5'

# For reading the .env file, which you can use in development to more easily
# set environment variables for secret data.
gem 'dotenv-rails', '~> 2.8', '>= 2.8.1'

# For the asset pipeline: templates, CSS, JS, etc.
gem 'sprockets', '~> 4.2'
gem 'haml', '~> 6.1', '>= 6.1.1'
gem 'sass-rails', '~> 6.0'
gem 'terser', '~> 1.1', '>= 1.1.17'
gem 'react-rails', '~> 2.7', '>= 2.7.1'
gem 'jsbundling-rails', '~> 1.3'
gem 'turbo-rails', '~> 2.0'

# For authentication.
gem 'devise', '~> 4.9', '>= 4.9.2'
gem 'devise-encryptable', '~> 0.2.0'
gem 'omniauth', '~> 2.1'
gem 'omniauth-rails_csrf_protection', '~> 1.0'
gem "omniauth_openid_connect", "~> 0.7.1"

# For pagination UI.
gem 'will_paginate', '~> 4.0'

# For translation, both for the site UI and for Neopets data.
gem 'rails-i18n', '~> 7.0', '>= 7.0.7'
gem 'http_accept_language', '~> 2.1', '>= 2.1.1'

# For reading and parsing HTML from Neopets.com, like importing Closet pages.
gem 'nokogiri', '~> 1.15', '>= 1.15.3'

# For safely rendering users' Markdown + HTML on item list pages.
gem 'rdiscount', '~> 2.2', '>= 2.2.7.1'
gem 'sanitize', '~> 6.0', '>= 6.0.2'

# For working with Neopets APIs.
# unstable version of RocketAMF interprets info registry as a hash instead of an array
gem 'RocketAMF', :git => 'https://github.com/rubyamf/rocketamf.git'

# For preventing too many modeling attempts.
gem 'rack-attack', '~> 6.7'

# For testing emails in development.
gem 'letter_opener', '~> 1.8', '>= 1.8.1', group: :development

# For parallel API calls.
gem 'parallel', '~> 1.23'

# For miscellaneous HTTP requests.
gem "httparty", "~> 0.22.0"
gem "addressable", "~> 2.8"

# For advanced batching of many HTTP requests.
gem "async", "~> 2.17", require: false
gem "async-http", "~> 0.75.0", require: false
gem "thread-local", "~> 1.1", require: false

# For debugging.
group :development do
	gem 'debug', '~> 1.9.2'
	gem 'web-console', '~> 4.2'
end

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', '~> 1.16', require: false

# For investigating performance issues.
gem "rack-mini-profiler", "~> 3.1"
gem "memory_profiler", "~> 1.0"
gem "stackprof", "~> 0.2.25"

# For monitoring errors in production.
gem "sentry-ruby", "~> 5.12"
gem "sentry-rails", "~> 5.12"

# For tasks that use shell commands.
gem "shell", "~> 0.8.1"

# For workspace autocomplete.
group :development do
	gem "solargraph", "~> 0.50.0"
	gem "solargraph-rails", "~> 1.1"
end

# For automated tests.
group :development, :test do
	gem "rspec-rails", "~> 7.0"
	gem "webmock", "~> 3.24", group: :test
end
