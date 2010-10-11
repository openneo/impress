source 'http://rubygems.org'

gem 'rails', '3.0.0'
#gem 'sqlite3-ruby', '~> 1.3.1', :require => 'sqlite3'

gem 'compass', '~> 0.10.1'
gem 'haml', '~> 3.0.18'
gem 'rdiscount', '~> 1.6.5'
gem 'RocketAMF', '~> 0.2.1'
gem 'will_paginate', '~> 3.0.pre2'

gem 'jammit', '~> 0.5.3'

group :development_async, :production do
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
  gem 'addressable', :require => 'addressable/uri'
end

group :test do
  gem 'factory_girl_rails', '~> 1.0'
  gem 'rspec-rails', '~> 2.0.0.beta.22'
end
