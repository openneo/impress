class AuthUser < AuthRecord
  self.table_name = 'users'

  devise :database_authenticatable, :encryptable, :registerable, :validatable,
    :rememberable, :trackable, :recoverable, :omniauthable,
    omniauth_providers: [:neopass]

  validates :name, presence: true, uniqueness: {case_sensitive: false},
    length: {maximum: 30}

  validates :uid, uniqueness: {scope: :provider, allow_nil: true}

  validate :has_at_least_one_login_method
  
  has_one :user, foreign_key: :remote_id, inverse_of: :auth_user

  # If the email is blank, ensure that it's `nil` rather than an empty string,
  # or else the database's uniqueness constraint will object to multiple users
  # who all have the empty string as their email.
  before_validation { self.email = nil if email.blank? }
  
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
    # Email is required when creating a new account from scratch, but it isn't
    # required when creating a new account via third-party login (e.g. it's
    # already taken). It's also okay to remove your email address, though this
    if new_record?
      # When creating a new account, email is required when building it from
      # scratch, but not required when using third-party login. This is mainly
      # because third-party login can't reliably offer an unused email!
      !uses_omniauth?
    else
      # TODO: I had wanted to make email required if you already have one, to
      #       make it harder to accidentally remove? I expected
      #       `email_before_last_save` to be the way to check this, but it
      #       seemed to be `nil` when calling this, go figure! For now, we're
      #       allowing email to be removed.
      #
      # NOTE: This is important for the case where you're disconnecting a
      #       NeoPass, but you don't have an email set, because your NeoPass
      #       email already belonged to another account. I don't think it makes
      #       sense to require people to add an alternate real email address in
      #       order to be able to disconnect a NeoPass from a DTI account they
      #       maybe even created by accident!
      false
    end
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

  def update_with_password(params)
    # If this account already uses passwords, use Devise's default behavior.
    return super(params) if uses_password?

    # Otherwise, we implement similar logic, but skipping the check for
    # `current_password`: Bulk-assign most attributes, but only set the
    # password if it's non-empty.
    self.attributes = params.except(:password, :password_confirmation,
      :current_password)
    if params[:password].present?
      self.password = params[:password]
      self.password_confirmation = params[:password_confirmation]
    end

    self.save
  end

  def connect_omniauth!(auth)
    raise MissingAuthInfoError, "Email missing" if auth.info.email.blank?

    begin
      update!(provider: auth.provider, uid: auth.uid,
              neopass_email: auth.info.email)
    rescue ActiveRecord::RecordInvalid
      # If this auth is already bound to another account, raise a specific
      # error about it, instead of the normal error.
      if errors.where(:uid).any? { |e| e.type == :taken }
        raise AuthAlreadyConnected, "there's already an account with " +
          "provider #{auth.provider}, uid #{auth.uid}"
      end
      raise
    end
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

  def has_at_least_one_login_method
    if !uses_password? && !email? && !uses_neopass?
      errors.add(:base, "You must have either a password, an email, or a " +
        "NeoPass. Otherwise, you can't log in!")
    end
  end

  def self.find_by_omniauth(auth)
    find_by(provider: auth.provider, uid: auth.uid)
  end

  def self.from_omniauth(auth)
    raise MissingAuthInfoError, "Email missing" if auth.info.email.blank?

    transaction do
      find_or_create_by!(provider: auth.provider, uid: auth.uid) do |user|
        # This account is new! Let's do the initial setup.

        # First, get the user's Neopets username if possible, as a base for the
        # name we create for them. (This is an async task under the hood, which
        # means we can wrap it in a `with_timeout` block!)
        neopets_username = Sync do |task|
          task.with_timeout(5) do
            NeoPass.load_main_neopets_username(auth.credentials.token)
          end
        rescue Async::TimeoutError
          nil # If the request times out, just move on!
        rescue => error
          # If the request fails, log it and move on. (Could be a service
          # outage, or a change on NeoPass's end that we're not in sync with.)
          Rails.logger.error error
          Sentry.capture_exception error
          nil
        end

        # Generate a unique username for this user, based on their Neopets
        # username, if they have one.
        user.name = build_unique_username(neopets_username)

        # Copy the email address from their Neopets account to their DTI
        # account, unless they already have a DTI account with this email, in
        # which case, ignore it. (It's primarily for their own convenience with
        # password recovery!)
        email_exists = AuthUser.where(email: auth.info.email).exists?
        user.email = auth.info.email unless email_exists

        # Additionally, regardless of whether we save it as `email`, we also
        # save the email address as `neopass_email`, to use in the Settings UI
        # to indicate what NeoPass you're linked to.
        user.neopass_email = auth.info.email
      end.tap do |user|
        # If this account already existed, make sure we've saved the latest
        # email to `neopass_email`. (In practice, this *shouldn't* ever change
        # after initial setup, because NeoPass emails are immutable? But why
        # not be resilient!)
        unless user.previously_new_record?
          user.update!(neopass_email: auth.info.email)
        end
      end
    end
  end

  def self.build_unique_username(preferred_name = nil)
    # If there's no preferred name provided (ideally the user's Neopets
    # username), start with a base name like `neopass-kougra`.
    if preferred_name.present?
      base_name = preferred_name
    else
      random_species_name = Species.all.pluck(:name).sample
      base_name = "neopass-#{random_species_name}"
    end

    # Fetch the list of names that already start with that.
    name_query = sanitize_sql_like(base_name) + "%"
    similar_names = where("name LIKE ?", name_query).pluck(:name).to_set

    # If this was the user's preferred name (rather than a random one), try
    # using the preferred name itself, if not already taken.
    if preferred_name.present? && !similar_names.include?(preferred_name)
      return preferred_name
    end

    # Otherwise, shuffle the list of four-digit numbers to create 10000
    # possible names, then use the first one that's not already claimed.
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

  class AuthAlreadyConnected < ArgumentError;end
  class MissingAuthInfoError < ArgumentError;end
end