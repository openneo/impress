class UsersController < ApplicationController
  def top_contributors
    @users = User.top_contributors.paginate :page => params[:page], :per_page => 20
  end
end
