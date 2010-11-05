require 'warden'

module Openneo
  module Auth
    class Strategy < Warden::Strategies::Base
      def valid?
        session && session[:session_id]
      end
      
      def authenticate!
        begin
          auth_session = Session.find session[:session_id]
        rescue Session::NotFound => e
          fail! e.message
        else
          auth_session.destroy!
          success! auth_session.user
        end
      end
    end
  end
end
