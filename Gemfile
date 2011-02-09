source 'http://rubygems.org'

gem 'rails', '3.0.4'
#gem 'sqlite3-ruby', '~> 1.3.1', :require => 'sqlite3'

gem 'compass', '~> 0.10.1'
gem 'haml', '~> 3.0.18'
gem 'rdiscount', '~> 1.6.5'
gem 'will_paginate', '~> 3.0.pre2'
gem 'devise', '~> 1.1.5'

# unstable version of RocketAMF interprets info registry as a hash instead of an array
gem 'RocketAMF', :git => 'git://github.com/warhammerkid/rocket-amf.git'

gem 'msgpack', '~> 0.4.3'
gem 'openneo-auth-signatory', '~> 0.1.0'

gem 'jammit', '~> 0.5.3'

gem 'hoptoad_notifier'

gem 'addressable', :require => ['addressable/template', 'addressable/uri']

gem 'whenever', '~> 0.6.2', :require => false

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
  gem 'thin', '~> 1.2.7'
  
  gem 'memcache-client', '~> 1.8.5', :require => ['memcache', 'memcache/event_machine']
end

group :test do
  gem 'factory_girl_rails', '~> 1.0'
  gem 'rspec-rails', '~> 2.0.0.beta.22'
end
