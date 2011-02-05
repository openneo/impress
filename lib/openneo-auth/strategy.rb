require 'devise'

module Openneo
  module Auth
    module Strategies
      class Token < Devise::Strategies::Authenticatable
        def valid?
          session && session[:session_id]
        end
        
        def authenticate!
          begin
            auth_session = Session.find session[:session_id]
          rescue Session::NotFound => e
            pass
          else
            auth_session.destroy!
            success! auth_session.user
          end
        end
        
        def remember_me?
          true
        end
      end
    end
  end
end
