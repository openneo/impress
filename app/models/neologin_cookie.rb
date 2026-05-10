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
      notified_failure_at: nil,
    )
  end

  # Record that this cookie failed to authenticate. Fires a Discord webhook
  # the *first* time a cookie fails after a successful run, so a flapping
  # task doesn't spam the channel.
  def record_failure!(message:, now: Time.current)
    should_notify = notified_failure_at.nil?

    update_columns(
      last_failed_at: now,
      last_failure_message: message.to_s.truncate(1000),
      notified_failure_at: should_notify ? now : notified_failure_at,
    )

    DiscordNotifier.notify_neologin_failure(self, message:) if should_notify
  end

  # Whether this cookie is currently in a failed state (i.e. has failed since
  # its last successful use, or has never succeeded and has failed).
  def failing?
    return false if last_failed_at.nil?
    return true if last_used_successfully_at.nil?
    last_failed_at > last_used_successfully_at
  end
end
