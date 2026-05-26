require "net/http"

# Sends notifications to Discord via incoming webhooks. Currently only used to
# alert when our Neologin cookie stops working, so the right people can rotate
# it.
#
# The webhook URL is read from NEOLOGIN_DISCORD_WEBHOOK_URL. If unset, we log
# the would-be notification and move on — useful in dev/test, and avoids
# blocking the rake task on a misconfigured webhook in production.
module DiscordNotifier
  WEBHOOK_ENV_VAR = "NEOLOGIN_DISCORD_WEBHOOK_URL"

  def self.notify_neologin_refreshed(cookie)
    who = cookie.created_by&.name || "someone"
    content = "✅ **Neologin cookie refreshed** by #{who} — import tasks are back online."
    post(content:)
  end

  def self.notify_neologin_failure(cookie, message:)
    age = ApplicationController.helpers.time_ago_in_words(cookie.created_at)
    content =
      "🚨 **Neologin cookie failed!** The current cookie (saved #{age} ago) " \
      "isn't working. Please rotate it at <#{admin_url}>.\n" \
      "```\n#{message.to_s.truncate(500)}\n```"

    post(content:)
  end

  def self.post(content:)
    url = ENV[WEBHOOK_ENV_VAR]
    if url.blank?
      Rails.logger.warn(
        "[DiscordNotifier] #{WEBHOOK_ENV_VAR} not set; would have sent: #{content}"
      )
      return
    end

    uri = URI.parse(url)
    response = Net::HTTP.post(
      uri,
      { content: }.to_json,
      "Content-Type" => "application/json",
    )
    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.error(
        "[DiscordNotifier] webhook POST failed: #{response.code} #{response.body}"
      )
    end
  rescue => e
    # A broken webhook should never break the caller — we already have Sentry
    # for the underlying failure that triggered the notification.
    Rails.logger.error("[DiscordNotifier] error posting webhook: #{e.message}")
    Sentry.capture_exception(e) if defined?(Sentry)
  else
    Rails.logger.info("[DiscordNotifier] Posted message: #{content}")
  end

  def self.admin_url
    Rails.application.routes.url_helpers.admin_neologin_cookies_url(
      host: Rails.application.config.action_mailer.default_url_options&.dig(:host) || "impress.openneo.net",
      protocol: "https",
    )
  rescue
    "https://impress.openneo.net/admin/neologin"
  end
end
