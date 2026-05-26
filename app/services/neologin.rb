# Provides the current Neopets login cookie for authenticated requests, and
# tracks whether it's actually working.
#
# Resolution order:
# 1. The most recent NeologinCookie row, set via the admin panel.
# 2. The NEOLOGIN_COOKIE environment variable (handy for local dev / one-off
#    rake invocations before the admin panel has a value).
#
# Callers wrap authenticated requests like:
#
#     Neologin.with_tracking do
#       Neopets::NCMall.load_styles(...)
#     end
#
# which records a success on the current cookie if the block returns, or a
# failure (with Discord notification on first failure) if it raises.
module Neologin
  class MissingCookie < StandardError; end

  # Raised when Neopets explicitly rejects our cookie (e.g. responds with
  # `errType: "login"`). Distinct from a generic UnexpectedResponseFormat so
  # callers and the admin panel can surface "the cookie is expired" plainly,
  # instead of lumping it in with parser errors and other surprises.
  class CookieRejected < StandardError; end

  def self.cookie
    db_cookie = NeologinCookie.current&.cookie
    return db_cookie if db_cookie.present?
    return ENV["NEOLOGIN_COOKIE"] if ENV["NEOLOGIN_COOKIE"].present?
    raise MissingCookie, "no Neologin cookie configured (admin panel or " \
      "NEOLOGIN_COOKIE env var)"
  end

  def self.cookie?
    NeologinCookie.current&.cookie.present? || ENV["NEOLOGIN_COOKIE"].present?
  end

  # Run the block with success/failure tracking on the current DB cookie.
  # Records a success if the block returns, or a failure if it raises (then
  # re-raises). When the cookie is only configured via ENV (no DB row), there's
  # nothing to update — the block still runs, errors still propagate.
  def self.with_tracking
    record = NeologinCookie.current
    begin
      result = yield
      record&.record_success!
      result
    rescue => e
      record&.record_failure!(
        message: format_exception_chain(e),
        kind: failure_kind_for(e),
      )
      raise
    end
  end

  # Format an exception and its `cause` chain into a single readable string,
  # so we don't lose context when a low-level error (e.g. JSON::ParserError)
  # gets re-raised as a higher-level one (e.g. UnexpectedResponseFormat).
  def self.format_exception_chain(error)
    parts = []
    current = error
    seen = Set.new
    while current && seen.add?(current.object_id)
      parts << "#{current.class}: #{current.message}"
      current = current.cause
    end
    parts.join("\nCaused by: ")
  end

  # Authenticated wrappers around DTIRequests: inject the neologin cookie
  # header and intercept any Set-Cookie rotation in the response, so callers
  # don't have to manage either concern.
  def self.authed_get(url, headers = [], &block)
    DTIRequests.get(url, [["Cookie", "neologin=#{cookie}"], *headers]) do |response|
      record_rotation_if_applicable!(response)
      block.call(response)
    end
  end

  def self.authed_post(url, headers = [], body = nil, &block)
    DTIRequests.post(url, [["Cookie", "neologin=#{cookie}"], *headers], body) do |response|
      record_rotation_if_applicable!(response)
      block.call(response)
    end
  end

  # Check a Neopets HTTP response for a Set-Cookie header that rotates the
  # neologin value. If found and different from what we have stored, updates
  # the current DB record in-place.
  def self.record_rotation_if_applicable!(response)
    record = NeologinCookie.current
    return unless record

    new_cookie = extract_neologin_cookie_value(response)
    return unless new_cookie.present? && new_cookie != record.cookie

    record.record_rotation!(new_cookie)
  end

  def self.extract_neologin_cookie_value(response)
    response.headers.each do |name, value|
      next unless name == "set-cookie"
      match = value.match(/\Aneologin=([^;]+)/)
      return match[1] if match
    end
    nil
  end

  def self.failure_kind_for(error)
    return "expired" if error.is_a?(CookieRejected)
    nil
  end

  # Test whether a cookie value authenticates against Neopets, without saving
  # it first. Makes a POST to the Styling Studio (the same endpoint we use in
  # production) and checks for an explicit login rejection. Raises
  # CookieRejected if Neopets rejects it, or another error on network/parse
  # failures. Returns normally on success.
  TEST_ENDPOINT = "https://www.neopets.com/np-templates/ajax/stylingstudio/studio.php"
  def self.test!(cookie_value)
    Sync do
      DTIRequests.post(
        TEST_ENDPOINT,
        [
          ["Cookie", "neologin=#{cookie_value}"],
          ["Content-Type", "application/x-www-form-urlencoded"],
          ["X-Requested-With", "XMLHttpRequest"],
        ],
        "tab=3&mode=getTab&key=StylingStudioTab&value=3",
      ) do |response|
        data = JSON.parse(response.read).deep_symbolize_keys rescue {}
        if data.is_a?(Hash) && data[:error] && data[:errType] == "login"
          raise CookieRejected, data[:errMsg].presence || "Neopets rejected the cookie"
        end
      end
    end
  end

  # Service-account credentials for staff to use when refreshing the cookie.
  # Stored in env vars for convenience, not secrecy — the account is just a
  # shared login used to scrape public-ish Neopets data.
  def self.service_account_email
    ENV["NEOPETS_SERVICE_ACCOUNT_EMAIL"]
  end

  def self.service_account_password
    ENV["NEOPETS_SERVICE_ACCOUNT_PASSWORD"]
  end
end
