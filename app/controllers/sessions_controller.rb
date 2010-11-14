class SessionsController < ApplicationController
  rescue_from Openneo::Auth::Session::InvalidSignature, :with => :invalid_signature
  rescue_from Openneo::Auth::Session::MissingParam, :with => :missing_param
  
  before_filter :initialize_session, :only => [new]
  
  skip_before_filter :verify_authenticity_token, :only => [:create]
  
  def new
    redirect_to Openneo::Auth.remote_auth_url(params, session)
  end
  
  def create
    session = Openneo::Auth::Session.from_params(params)
    session.save!
    render :text => 'Success'
  end
  
  def destroy
    warden.logout
    cookies.delete :remember_me
    redirect_to (params[:return_to] || root_path)
  end
  
  protected
  
  def initialize_session
    session[:session_initialization_placeholder] = nil
  end
  
  def invalid_signature(exception)
    render :text => "Signature did not match. Check secret.",
      :status => :unprocessable_entity
  end
  
  def missing_param(exception)
    render :text => exception.message, :status => :unprocessable_entity
  end
end
