class LocalesController < ApplicationController
  def choose
    cookies.permanent[:locale] = params[:locale] if valid_locale?(params[:locale])
    if params[:return_to]
      redirect_to params[:return_to]
    else
      redirect_back fallback_location: root_path
    end
  end
end
