source 'http://rubygems.org'
ruby '2.2.4'

gem 'dotenv-rails'
gem 'dotenv-deployment'

gem 'rails', '= 4.0.13'
#gem 'sqlite3-ruby', '~> 1.3.1', :require => 'sqlite3'
gem 'mysql2', '>= 0.3.11'

gem 'haml', '~> 4.0.0'
gem 'rdiscount', '~> 1.6.5'
gem 'will_paginate', '~> 3.0.pre2'
gem 'devise', '~> 3.5.10'

# unstable version of RocketAMF interprets info registry as a hash instead of an array
gem 'RocketAMF', :git => 'https://github.com/rubyamf/rocketamf.git'

gem 'msgpack', '~> 0.5.3'
gem 'openneo-auth-signatory', '~> 0.1.0'

gem 'airbrake', '~> 3.1.8'

gem 'addressable', :require => ['addressable/template', 'addressable/uri']

gem 'whenever', '~> 0.7.3', :require => false

gem 'swf_converter', '~> 0.0.3'

gem 'resque', '~> 1.23.0'
gem 'resque-scheduler', '~> 2.0.0.d'
gem 'resque-retry', '~> 0.1.0'

gem 'right_aws', '~> 2.1.0'

gem "character-encodings", "~> 0.4.1", :platforms => :ruby_18

gem "nokogiri", "~> 1.5.2"

gem 'sanitize', '~> 2.0.3'

gem 'neopets', '~> 0.2.0', :git => 'https://github.com/matchu/neopets.git'

gem "mini_magick", "~> 3.4"

gem "fog", "~> 1.8.0"
gem 'carrierwave', '~> 1.3', '>= 1.3.3'

gem "parallel", "~> 1.13.0"

gem "http_accept_language", :git => "https://github.com/iain/http_accept_language.git"

gem 'globalize', '~> 4.0.3'

gem "rest-client", "~> 1.6.7"

gem 'rails-i18n', '~> 4.0', '>= 4.0.9'

gem 'rack-attack', '~> 2.2.0'

gem 'react-rails', '~> 2.7', '>= 2.7.1'

gem "letter_opener", :group => :development

gem 'sass-rails',    "~> 4.0.5"
gem 'compass-rails', "~> 1.0.3"
gem 'uglifier',      ">= 1.0.3"

gem 'rails-observers', '~> 0.1.5'

group :development do
  gem 'capistrano', '~> 2.15.5', require: false
  gem 'rvm-capistrano', '~> 1.5.6', require: false
end

group :production do
  gem 'memcache-client', '~> 1.8.5', :require => 'memcache'
  gem 'passenger_monit', '~> 0.1.1'
end

group :test do
  gem 'factory_girl_rails', '~> 1.0'
  gem 'rspec-rails', '~> 2.0.0.beta.22'
end
