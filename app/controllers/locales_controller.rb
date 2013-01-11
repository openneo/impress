class LocalesController < ApplicationController
  def choose
    cookies.permanent[:locale] = params[:locale] if valid_locale?(params[:locale])
    origin = params[:return_to] || :back
    redirect_to origin
  end
end
