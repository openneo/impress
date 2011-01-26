require 'warden'

module Openneo
  module Auth
    module Strategies
      class Token < Warden::Strategies::Base
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
            auth_session.user.remember_me!
            success! auth_session.user
          end
        end
      end
    end
  end
end
