require_relative '../rails_helper'
require_relative '../support/account_data_helpers'

# Checks the Warden hook in config/initializers/warden_authenticated_at.rb
# against a real login, rather than Devise's test helpers (which skip hooks).
RSpec.describe "Recording when a session logged in", :account_data, type: :request do
  include ActiveSupport::Testing::TimeHelpers
  it "records the login time in the session" do
    create_account("Recent")

    freeze_time do
      post auth_user_session_path,
        params: {auth_user: {name: "recent", password: "password123"}}

      expect(response).to have_http_status(:redirect)
      expect(session["warden.user.auth_user.session"]).
        to include("authenticated_at" => Time.now.to_i)
    end
  end
end
