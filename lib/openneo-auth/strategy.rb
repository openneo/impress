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
            cookies.permanent.signed[:remember_me] = auth_session.user.id
            success! auth_session.user
          end
        end
      end
      
      class Remember < Warden::Strategies::Base
        def valid?
          cookies.signed[:remember_me]
        end
        
        def authenticate!
          user = Auth.config.find_user_by_remembering cookies.signed[:remember_me]
          if user
            success! user
          else
            fail!
          end
        end
      end
    end
  end
end
