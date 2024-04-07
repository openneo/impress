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

  def uses_neopass?
    provider == "neopass"
  end

  def neopass_friendly_id
    neopass_email || uid
  end

  def uses_password?
    encrypted_password?
  end

  def disconnect_neopass
    # If there's no NeoPass, we're already done!
    return true if !uses_neopass?

    begin
      # Remove all of the NeoPass fields, and return whether we were
      # successful. (I don't know why it wouldn't be, but let's be resilient!)
      #
      # NOTE: I considered leaving `neopass_email` in place, to help us support
      #       users who accidentally got locked out… but I think it's more
      #       important to respect data privacy and not be holding onto an
      #       email address the user doesn't realize we have!
      update(provider: nil, uid: nil, neopass_email: nil)
    rescue => error
      # If something strange happens, log it and gracefully return `false`!
      Sentry.capture_exception error
      Rails.logger.error error
      false
    end
  end

  def self.from_omniauth(auth)
    raise MissingAuthInfoError, "Email missing" if auth.info.email.blank?

    transaction do
      find_or_create_by!(provider: auth.provider, uid: auth.uid) do |user|
        # This account is new! Let's do the initial setup.

        # TODO: Can we somehow get the Neopets username if one exists, instead
        # of just using total randomness?
        user.name = build_unique_username

        # Copy the email address from their Neopets account to their DTI
        # account, unless they already have a DTI account with this email, in
        # which case, ignore it. (It's primarily for their own convenience with
        # password recovery!)
        email_exists = AuthUser.where(email: auth.info.email).exists?
        user.email = auth.info.email unless email_exists
      end.tap do |user|
        # Additionally, whether this account is new or existing, make sure
        # we've saved the latest email to `neopass_email`.
        #
        # We track this separately from `email`, which the user can edit, to
        # use in the Settings UI to indicate what NeoPass you're linked to. (In
        # practice, this *shouldn't* ever change after initial setup, because
        # NeoPass emails are immutable? But why not be resilient!)
        user.update!(neopass_email: auth.info.email)
      end
    end
  end

  def self.build_unique_username
    # Start with a base name like "neopass-kougra-".
    random_species_name = Species.all.pluck(:name).sample
    base_name = "neopass-#{random_species_name}"

    # Fetch the list of names that already start with that.
    name_query = sanitize_sql_like(base_name) + "%"
    similar_names = where("name LIKE ?", name_query).pluck(:name).to_set

    # Shuffle the list of four-digit numbers to create 10000 possible names,
    # then use the first one that's not already claimed.
    potential_names = (0..9999).map { |n| "#{base_name}-#{n}" }.shuffle
    name = potential_names.find { |name| !similar_names.include?(name) }
    return name unless name.nil?

    # If that failed, try again but with six digits.
    potential_names = (0..999999).map { |n| "#{base_name}-#{n}" }.shuffle
    name = potential_names.find { |name| !similar_names.include?(name) }
    return name unless name.nil?

    # If *that* failed, then golly gee, we have millions of NeoPass users
    # running around using the default username. Good for us, I guess?? If so,
    # uhh, let's cross that bridge when we come to it. (At time of writing,
    # there are about 60k total registered DTI users at *all*.)
    raise "Failed to build unique username (all million+ names starting with " +
      "\"#{base_name}\" are taken??)"
  end

  class MissingAuthInfoError < ArgumentError;end
end