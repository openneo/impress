source 'http://rubygems.org'

gem 'rails', '3.0.20'
#gem 'sqlite3-ruby', '~> 1.3.1', :require => 'sqlite3'

gem 'compass', '~> 0.10.1'
gem 'haml', '~> 3.0.18'
gem 'rdiscount', '~> 1.6.5'
gem 'will_paginate', '~> 3.0.pre2'
gem 'devise', '~> 1.1.5'

# unstable version of RocketAMF interprets info registry as a hash instead of an array
gem 'RocketAMF', :git => 'git://github.com/rubyamf/rocketamf.git'

gem 'msgpack', '~> 0.4.3'
gem 'openneo-auth-signatory', '~> 0.1.0'

gem 'jammit', '~> 0.5.3'

gem 'hoptoad_notifier'

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

gem 'newrelic_rpm'

gem 'neopets', '~> 0.2.0', :git => 'git://github.com/matchu/neopets.git'

gem "mini_magick", "~> 3.4"

gem "fog", "~> 1.8.0"
gem "carrierwave", "~> 0.5.8"

gem "parallel", "~> 0.5.17"

gem "http_accept_language", :git => "git://github.com/iain/http_accept_language.git"

gem "globalize3", :git => "git://github.com/matchu/globalize3.git"

# My flex branch fixes a minor pagination bug. Once it's merged into the
# original gem, we can switch back.
gem "flex", :require => "flex/rails", :git => "git://github.com/matchu/flex.git"
gem "patron", "~> 0.4.18"

gem "rest-client", "~> 1.6.7"

gem "rails-i18n"

group :development do
  gem "bullet", "~> 4.1.5"
end

group :development_async do
  # async wrappers
  gem 'eventmachine',     :git => 'git://github.com/eventmachine/eventmachine.git'
  gem 'rack-fiber_pool',  :require => 'rack/fiber_pool'
  gem 'em-synchrony',     :git => 'git://github.com/igrigorik/em-synchrony.git', :require => [
    'em-synchrony',
    'em-synchrony/em-http'
    ]

  # async activerecord requires
  gem 'mysqlplus',      :git => 'git://github.com/oldmoe/mysqlplus.git',        :require => 'mysqlplus'
  gem 'em-mysqlplus',   :git => 'git://github.com/igrigorik/em-mysqlplus.git',  :require => 'em-activerecord'

  # async http requires
  gem 'em-http-request',:git => 'git://github.com/igrigorik/em-http-request.git', :require => 'em-http'
end

group :production do
  gem 'mysql2', '< 0.3'
  gem 'memcache-client', '~> 1.8.5', :require => 'memcache'
end

group :test do
  gem 'factory_girl_rails', '~> 1.0'
  gem 'rspec-rails', '~> 2.0.0.beta.22'
end

