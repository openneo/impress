require "bundler/capistrano"
require "dotenv/deployment/capistrano"
require "rvm/capistrano"
require "whenever/capistrano"

set :application, "newimpress.openneo.net"
set :repository, "git://github.com/matchu/openneo-impress-rails.git"
set :deploy_to, "/home/rails/impress"
set :user, "rails"
set :branch, "master"
default_run_options[:pty] = true

set :scm, :git
# Or: `accurev`, `bzr`, `cvs`, `darcs`, `git`, `mercurial`, `perforce`, `subversion` or `none`

role :web, application
role :app, application, :memcached => true
role :db,  application, :primary => true

set :bundle_without, [:development, :test]

set :rvm_ruby_string, 'ruby-1.9.3-p484'        # Or whatever env you want it to run in.
set :rvm_type, :system
set :rvm_install_type, :head
set :rvm_bin_path, "/usr/local/rvm/bin"

set :whenever_command, "bundle exec whenever"

namespace :deploy do
  task :start, :roles => :app do
    run "touch #{current_release}/tmp/restart.txt"
    sudo "monit -g impress_workers start"
  end

  task :stop do
    sudo "monit -g impress_workers stop"
  end

  task :restart do
    run "touch #{current_release}/tmp/restart.txt"
    sudo "monit -g impress_workers restart"
  end

  desc "Link shared files"
  task :link do
    links = {
      "#{shared_path}/app/views/static/_announcement.html" => "#{release_path}/app/views/static/_announcement.html",
      #"#{shared_path}/config/aws_s3.yml" => "#{release_path}/config/aws_s3.yml",
      "#{shared_path}/config/database.yml" => "#{release_path}/config/database.yml",
      #"#{shared_path}/config/openneo_auth.yml" => "#{release_path}/config/openneo_auth.yml",
      #"#{shared_path}/config/initializers/secret_token.rb" => "#{release_path}/config/initializers/secret_token.rb",
      #"#{shared_path}/config/initializers/stripe.rb" => "#{release_path}/config/initializers/stripe.rb"
      "#{shared_path}/public/beta.html" => "#{release_path}/public/beta.html",
      "#{shared_path}/public/javascripts/analytics.js" => "#{release_path}/app/assets/javascripts/analytics.js",
      "#{shared_path}/public/swfs/outfit" => "#{release_path}/public/swfs/outfit",
      "#{shared_path}/.rvmrc" => "#{release_path}/.rvmrc"
    }
    links.each do |specific_shared_path, specific_release_path|
      run "rm -rf #{specific_release_path} && ln -nfs #{specific_shared_path} #{specific_release_path}"
    end
  end
end

namespace :memcached do
  desc "Start memcached"
  task :start, :roles => [:app], :only => {:memcached => true} do
    sudo "/etc/init.d/memcached start"
  end
  desc "Stop memcached"
  task :stop, :roles => [:app], :only => {:memcached => true} do
    sudo "/etc/init.d/memcached stop"
  end
  desc "Restart memcached"
  task :restart, :roles => [:app], :only => {:memcached => true} do
    sudo "/etc/init.d/memcached restart"
  end
  desc "Flush memcached - this assumes memcached is on port 11211"
  task :flush, :roles => [:app], :only => {:memcached => true} do
    run "echo 'flush_all' | nc localhost 11211"
  end
  desc "Symlink the memcached.yml file into place if it exists"
  task :symlink_configs, :roles => [:app], :only => {:memcached => true }, :except => { :no_release => true } do
    run "if [ -f #{shared_path}/config/memcached.yml ]; then ln -nfs #{shared_path}/config/memcached.yml #{latest_release}/config/memcached.yml; fi"
  end
end

before "deploy:symlink", "memcached:flush"
after "deploy:update_code", "deploy:link"

