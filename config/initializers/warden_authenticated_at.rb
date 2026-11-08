# Remember when *this session* last actually logged in, as opposed to Devise's
# `current_sign_in_at`, which is shared by every session for the account. We
# use this for "you must have logged in recently" checks, like deleting an
# account that has no password.
#
# This runs for real logins (password, NeoPass, and remember-me cookies), but
# not for loading an existing session on each request.
#
# NOTE: Because remember-me cookie logins count too, this means "this browser
#       proved it's you recently", with up to a remember-me period of slack.
#       That's fine for NeoPass-only accounts today, since NeoPass login
#       doesn't set remember-me, but keep it in mind if you reuse this!
Warden::Manager.after_authentication do |record, warden, options|
  warden.session(options[:scope])["authenticated_at"] = Time.now.to_i
end
