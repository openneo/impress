require 'openneo-auth/session'
require 'openneo-auth/strategy'

Warden::Strategies.add :openneo_auth_token, Openneo::Auth::Strategy

module Openneo
  module Auth
    class Config
      attr_accessor :app, :auth_server, :secret
      
      def find_user(data)
        raise "Must set a user finder for Openneo Auth to find a user" unless @user_finder
        @user_finder.call(data)
      end
      
      def user_finder(&block)
        @user_finder = block
      end
    end
      
    class << self
      def config
        @@config ||= Config.new
      end
      
      def configure(&block)
        block.call(config)
      end
      
      def remote_auth_url(params, session)
        raise "Must set config.app to this app's subdomain" unless config.app
        raise "Must set config.auth_server to remote server's hostname" unless config.auth_server
        query = {
          :app => config.app,
          :session_id => session[:session_id],
          :path => params[:return_to] || '/'
        }.to_query
        uri = URI::HTTP.build({
          :host => config.auth_server,
          :path => '/',
          :query => query
        })
        uri.to_s
      end
    end
  end
end
