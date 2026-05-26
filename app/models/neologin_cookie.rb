class NeologinCookie < ApplicationRecord
  belongs_to :created_by, class_name: "User", optional: true

  validates :cookie, presence: true

  scope :recent_first, -> { order(created_at: :desc) }

  # The most recently saved cookie. The DB is append-only so older cookies stay
  # around as an audit log, but only the latest is the one we send to Neopets.
  def self.current
    recent_first.first
  end

  # Record that this cookie successfully authenticated against Neopets.
  # Clears any pending failure state so a future failure will re-notify.
  def record_success!(now: Time.current)
    update_columns(
      last_used_successfully_at: now,
      last_failed_at: nil,
      last_failure_message: nil,
      last_failure_kind: nil,
      notified_failure_at: nil,
    )
  end

  # Record that this cookie failed to authenticate. Fires a Discord webhook
  # the *first* time a cookie fails after a successful run, so a flapping
  # task doesn't spam the channel.
  #
  # Uses a DB row lock so concurrent async callers (e.g. parallel species
  # requests in the styling_studio task) don't each see notified_failure_at
  # as nil and fire duplicate webhooks.
  def record_failure!(message:, kind: nil, now: Time.current)
    should_notify = with_lock do
      reload
      notify = notified_failure_at.nil?
      update_columns(
        last_failed_at: now,
        last_failure_message: message.to_s.truncate(1000),
        last_failure_kind: kind,
        notified_failure_at: notify ? now : notified_failure_at,
      )
      notify
    end

    DiscordNotifier.notify_neologin_failure(self, message:) if should_notify
  end

  # Record that Neopets auto-rotated the cookie in a Set-Cookie response
  # header. Updates the stored value in-place (no new audit row) and stamps
  # last_rotated_at so the admin panel can show rotation is happening.
  def record_rotation!(new_cookie, now: Time.current)
    update_columns(cookie: new_cookie, last_rotated_at: now)
  end

  # True when our most recent failure was Neopets explicitly rejecting the
  # cookie (vs. a parser error, network blip, etc). Lets the admin UI show
  # a clearer "expired, please refresh" state.
  def expired?
    failing? && last_failure_kind == "expired"
  end

  # Whether this cookie is currently in a failed state (i.e. has failed since
  # its last successful use, or has never succeeded and has failed).
  def failing?
    return false if last_failed_at.nil?
    return true if last_used_successfully_at.nil?
    last_failed_at > last_used_successfully_at
  end
end
