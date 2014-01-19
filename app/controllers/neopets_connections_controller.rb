class NeopetsConnectionsController < ApplicationController
  def create
    connection = authorized_user.neopets_connections.build
    connection.neopets_username = params[:neopets_connection][:neopets_username]
    if connection.save
      render json: connection
    else
      render json: {error: 'failure'}, status: :internal_server_error
    end
  end

  def destroy
    connection = authorized_user.neopets_connections.find_by_neopets_username(params[:id])
    if connection
      if connection.destroy
        render json: connection
      else
        render json: {error: 'failure'}, status: :internal_server_error
      end
    else
      render json: {error: 'not found'}, status: :not_found
    end
  end

  def authorized_user
    if user_signed_in? && current_user.id == params[:user_id].to_i
      current_user
    else
      raise AccessDenied
    end
  end
end
