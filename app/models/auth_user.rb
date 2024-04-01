class AuthUser < AuthRecord
  self.table_name = 'users'

  devise :database_authenticatable, :encryptable, :registerable, :validatable,
    :rememberable, :trackable, :recoverable, :omniauthable,
    omniauth_providers: [:neopass]

  validates :name, presence: true, uniqueness: {case_sensitive: false},
    length: {maximum: 30}
  
  has_one :user, foreign_key: :remote_id, inverse_of: :auth_user
  
  # It's important to keep AuthUser and User in sync. When we create an AuthUser
  # (e.g. through the registration process), we create a matching User, too. And
  # when the AuthUser's name changes, we update User to match.
  #
  # TODO: Should we sync deletions too? We don't do deletions anywhere in app
  # right now, so I'll hold off to avoid leaving dead code around.
  after_create :create_user!
  after_update :sync_name_with_user!, if: :saved_change_to_name?

  def create_user!
    User.create!(name: name, auth_server_id: 1, remote_id: id)
  end

  def sync_name_with_user!
    user.name = name
    user.save!
  end

  def uses_omniauth?
    provider? && uid?
  end

  def email_required?
    !uses_omniauth?
  end

  def password_required?
    super && !uses_omniauth?
  end

  def self.from_omniauth(auth)
    raise MissingAuthInfoError, "Username missing" if auth.uid.blank?
    raise MissingAuthInfoError, "Email missing" if auth.info.email.blank?

    transaction do
      find_or_create_by!(provider: auth.provider, uid: auth.uid) do |user|
        # Use the Neopets username if possible, or a unique username if not.
        dti_username = build_unique_username_like(auth.uid)
        user.name = dti_username

        # Copy the email address from their Neopets account to their DTI
        # account, unless they already have a DTI account with this email, in
        # which case, ignore it. (It's primarily for their own convenience with
        # password recovery!)
        email_exists = AuthUser.where(email: auth.info.email).exists?
        user.email = auth.info.email unless email_exists
      end
    end
  end

  def self.build_unique_username_like(name)
    name_query = sanitize_sql_like(name) + "%"
    similar_names = where("name LIKE ?", name_query).pluck(:name)

    # Use the given name itself, if we can.
    return name unless similar_names.include?(name)

    # If not, try appending "-neopass".
    return "#{name}-neopass" unless similar_names.include?("#{name}-neopass")

    # After that, try appending "-neopass-1", "-neopass-2", etc, until a
    # unique name arises. (We don't expect this to happen basically ever, but
    # it's nice to have a guarantee!)
    max = similar_names.size + 1
    candidates = (1..max).map { |n| "#{name}-neopass-#{n}"}
    numerical_name = candidates.find { |name| !similar_names.include?(name) }
    return numerical_name unless numerical_name.nil?

    raise "Failed to build unique username (shouldn't be possible?)"
  end

  class MissingAuthInfoError < ArgumentError;end
end