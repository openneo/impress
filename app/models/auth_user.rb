class AuthUser < AuthRecord
  self.table_name = 'users'

  devise :database_authenticatable, :encryptable, :registerable, :validatable
  # devise :database_authenticatable, :lockable, :registerable, :recoverable,
  #   :trackable, :validatable

  validates :name, presence: true, uniqueness: {case_sensitive: false},
    length: {maximum: 20}
  
  has_one :user, foreign_key: :remote_id, inverse_of: :auth_user
  
  # It's important to keep AuthUser and User in sync. When we create an AuthUser
  # (e.g. through the registration process), we create a matching User, too. And
  # when the AuthUser's name changes, we update User to match.
  #
  # TODO: Should we sync deletions too? We don't do deletions anywhere in app
  # right now, so I'll hold off to avoid leaving dead code around.
  after_create :create_user
  after_update :sync_name_with_user, if: :saved_change_to_name?

  def create_user
    User.create(name: name, auth_server_id: 1, remote_id: id)
  end

  def sync_name_with_user
    user.name = name
    user.save!
  end
end