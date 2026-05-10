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
      record&.record_failure!(message: "#{e.class}: #{e.message}")
      raise
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
