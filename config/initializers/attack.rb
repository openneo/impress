require "ipaddr"

# Rate limits! These protect our own servers (and Neopets's) from too many pet
# loads, and protect our users' accounts from password-guessing attacks.
#
# NOTE: These use `Rails.cache`, which is a null store in tests, so they don't
#       apply there unless a test configures a real cache.

module RackAttackHelpers
  # A signed cookie listing which accounts have logged in from this browser.
  # Logins and password resets from a browser that has already logged into an
  # account are exempt from that account's limits (but not the per-IP ones),
  # so an attacker can't lock someone out of their own account from their
  # usual device by spamming bad passwords. (This is OWASP's "device cookie"
  # approach to account lockout.)
  KNOWN_DEVICE_COOKIE = "known_login_device"
  KNOWN_DEVICE_MAX_ACCOUNTS = 5

  def self.remember_known_device(cookies, auth_user_id)
    ids = known_device_account_ids(cookies) - [auth_user_id]
    cookies.permanent.signed[KNOWN_DEVICE_COOKIE] = {
      value: (ids + [auth_user_id]).last(KNOWN_DEVICE_MAX_ACCOUNTS),
      httponly: true,
    }
  end

  def self.known_device_account_ids(cookies)
    ids = cookies.signed[KNOWN_DEVICE_COOKIE]
    ids.is_a?(Array) ? ids : []
  end

  # Whether this is a POST to the given path, allowing for an optional format
  # extension like ".json", because the Rails router accepts that too.
  #
  # NOTE: Rack::Attack normalizes the path before we see it, the same way the
  #       Rails router does, so e.g. "//users//sign_in/" arrives here as
  #       "/users/sign_in".
  def self.post_to?(req, path)
    req.post? && req.path.match?(%r{\A#{Regexp.escape(path)}(\.[^/.]+)?\z})
  end

  # The client's IP address, for rate-limiting purposes. IPv6 addresses are
  # grouped by their /64 prefix, because a single client usually controls a
  # whole /64, and could otherwise get a fresh rate limit for each address.
  def self.ip_key(req)
    ip = IPAddr.new(req.ip).native # (`native` unwraps IPv4-mapped addresses)
    ip.ipv6? ? "#{ip.mask(64)}/64" : ip.to_s
  rescue IPAddr::Error
    req.ip
  end

  # Which account a login or password reset request is trying to access, for
  # rate-limiting purposes. (`field` is the form field that identifies the
  # account, e.g. `"name"` for login.)
  #
  # We look up the actual account, rather than just using the text, because
  # many variations of a username all refer to the same account (e.g.
  # different capitalization, or accented letters, which our database
  # collation treats as equivalent). Otherwise, an attacker could get a fresh
  # rate limit for each spelling!
  #
  # Returns nil if this browser has logged into this account before (see
  # `KNOWN_DEVICE_COOKIE` above), to exempt it from the account's limits.
  def self.account_key(req, field)
    auth_user_params = params(req)["auth_user"]
    return nil unless auth_user_params.is_a?(Hash)

    # NOTE: Devise converts *any* value to a string (e.g. a JSON number like
    #       `12345` would log into an account named "12345"), so we do too.
    value = auth_user_params[field].to_s
    return nil if value.strip.empty?

    # NOTE: This is the same lookup that Devise does, including normalizing the
    #       value (e.g. stripping whitespace) according to our Devise config.
    auth_user = AuthUser.find_for_authentication(field.to_sym => value)
    if auth_user.nil?
      "#{field}:#{value.strip.downcase}"
    elsif known_device_account_ids(cookies(req)).include?(auth_user.id)
      nil
    else
      "auth_user:#{auth_user.id}"
    end
  end

  def self.cookies(req)
    ActionDispatch::Request.new(req.env).cookie_jar
  end

  # The request params, parsed the same way the controller will see them, so
  # this works for JSON request bodies too.
  def self.params(req)
    ActionDispatch::Request.new(req.env).parameters
  rescue StandardError
    # If we can't parse the params, then neither can the controller, so this
    # request won't get very far anyway. (The per-IP limits still apply, too.)
    {}
  end

  # Redirect to the given path, with a flash message explaining why.
  #
  # NOTE: The flash isn't loaded yet when Rack::Attack runs, so we load it
  #       ourselves, then save it back to the session before responding.
  def self.redirect_with_flash(req, location, flash_type, message)
    request = ActionDispatch::Request.new(req.env)
    request.flash[flash_type] = message
    request.commit_flash
    [303, {"location" => location, "content-type" => "text/plain"}, [message]]
  end

  # A response for API requests, which won't follow redirects.
  def self.too_many_requests(req, message)
    match_data = req.env["rack.attack.match_data"] || {}
    period = match_data[:period].to_i
    retry_after = period > 0 ? period - (Time.now.to_i % period) : 60
    [429, {"content-type" => "text/plain", "retry-after" => retry_after.to_s},
      [message]]
  end
end

# When someone logs in (by password, remember-me cookie, or NeoPass), remember
# this browser as a known device for their account.
Warden::Manager.after_authentication do |record, warden, options|
  if record.is_a?(AuthUser)
    RackAttackHelpers.remember_known_device(warden.cookies, record.id)
  end
end

Rack::Attack.throttle('pets/ip', limit: 3, period: 30.seconds) do |req|
  Rails.logger.debug "Pets hit? #{req.path.inspect} #{req.ip.inspect}"
  req.ip if req.path.start_with?('/pets/load')
end

# Logging in: Limit how many guesses an attacker can make, both from a single
# client (in case they try many accounts at once, e.g. passwords leaked from
# other sites), and against a single account (in case they spread their
# attempts across many IPs). We check the IP first, so that blocked clients
# don't cost us an account lookup.
Rack::Attack.throttle('logins/ip', limit: 30, period: 5.minutes) do |req|
  RackAttackHelpers.ip_key(req) if RackAttackHelpers.post_to?(req, "/users/sign_in")
end
Rack::Attack.throttle('logins/account', limit: 10, period: 10.minutes) do |req|
  if RackAttackHelpers.post_to?(req, "/users/sign_in")
    RackAttackHelpers.account_key(req, "name")
  end
end

# Password reset emails: Limit how many an attacker can send, both overall,
# and to any one person's inbox.
Rack::Attack.throttle('password_resets/ip', limit: 10, period: 1.hour) do |req|
  RackAttackHelpers.ip_key(req) if RackAttackHelpers.post_to?(req, "/users/password")
end
Rack::Attack.throttle('password_resets/account', limit: 3, period: 1.hour) do |req|
  if RackAttackHelpers.post_to?(req, "/users/password")
    RackAttackHelpers.account_key(req, "email")
  end
end

PETS_THROTTLE_MESSAGE = "We've received a lot of pet names from you " +
                        "recently, so we're giving our servers a break. Try " +
                        "again in a minute or so. Thanks!"
LOGINS_THROTTLE_MESSAGE = "There have been a lot of login attempts for this " +
                          "account or from your network recently, so we're " +
                          "pausing them for a few minutes, for safety. " +
                          "Please wait a bit, then try again!"
PASSWORD_RESETS_THROTTLE_MESSAGE = "We've sent a lot of password reset " +
                                   "emails recently, so we're taking a " +
                                   "break. Please check your inbox (and spam " +
                                   "folder!), or try again in an hour or so."

Rack::Attack.throttled_responder = lambda do |req|
  is_api_request = req.path.end_with?('.json')

  case req.env['rack.attack.matched']
  when 'pets/ip'
    if is_api_request
      [503, {}, [PETS_THROTTLE_MESSAGE]]
    else
      RackAttackHelpers.redirect_with_flash(req, "/", :warning,
        PETS_THROTTLE_MESSAGE)
    end
  when 'logins/ip', 'logins/account'
    if is_api_request
      RackAttackHelpers.too_many_requests(req, LOGINS_THROTTLE_MESSAGE)
    else
      RackAttackHelpers.redirect_with_flash(req, "/users/sign_in", :alert,
        LOGINS_THROTTLE_MESSAGE)
    end
  when 'password_resets/ip', 'password_resets/account'
    if is_api_request
      RackAttackHelpers.too_many_requests(req, PASSWORD_RESETS_THROTTLE_MESSAGE)
    else
      RackAttackHelpers.redirect_with_flash(req, "/users/password/new", :alert,
        PASSWORD_RESETS_THROTTLE_MESSAGE)
    end
  else
    [503, {}, ["Retry later"]]
  end
end
