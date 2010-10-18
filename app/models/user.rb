class User < ActiveRecord::Base
  DefaultAuthServerId = 1
  
  def self.find_or_create_from_remote_auth_data(user_data)
    user = find_or_initialize_by_remote_id_and_auth_server_id(
      user_data['id'],
      DefaultAuthServerId
    )
    if user.new_record?
      user.name = user_data['name']
      user.save
    end
    user
  end
end
