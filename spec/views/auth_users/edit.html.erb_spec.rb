require_relative '../../rails_helper'
require_relative '../../support/account_data_helpers'

RSpec.describe "auth_users/edit", :account_data, type: :view do
  def render_for(auth_user, persisted_auth_user: auth_user)
    assign(:auth_user, auth_user)
    assign(:persisted_auth_user, persisted_auth_user)
    render
  end

  it "shows the saved account in the deletion form, after a failed update" do
    # This mirrors `AuthUsersController#update`: `@auth_user` has unsaved
    # changes, and `@persisted_auth_user` is a fresh copy from the database.
    auth_user = create_account("Typo")
    persisted = AuthUser.find(auth_user.id)
    auth_user.name = "typedname"
    render_for(auth_user, persisted_auth_user: persisted)

    expect(rendered).to include(%(action="/auth_users/#{auth_user.id}"))
    expect(rendered).to include("Your username is <strong>typo</strong>")
    expect(rendered).not_to include("<strong>typedname</strong>")
  end

  it "hides deletion from support staff, even after a failed update" do
    auth_user = create_account("Staffer")
    auth_user.user.update!(support_staff: true)
    persisted = AuthUser.find(auth_user.id)
    auth_user.name = "typedname"
    render_for(auth_user, persisted_auth_user: persisted)

    expect(rendered).not_to include("Permanently delete your account")
  end

  it "offers data export and account deletion" do
    render_for(create_account("Leaving"))

    expect(rendered).to include("Download your data")
    expect(rendered).to include("Permanently delete your account")
    expect(rendered).to include("account_deletion[confirm_name]")
    expect(rendered).to include("account_deletion[current_password]")
  end

  it "explains the recent-login requirement to accounts without a password" do
    render_for(AuthUser.create!(name: "NeoPassUser", email: "np@example.com",
      provider: "neopass", uid: "np-123", neopass_email: "np@example.com"))

    expect(rendered).to include("within the last 30 minutes")
    expect(rendered).not_to include("account_deletion[current_password]")
  end

  it "doesn't offer deletion to support staff" do
    auth_user = create_account("Staff")
    auth_user.user.update!(support_staff: true)
    render_for(auth_user)

    expect(rendered).not_to include("Permanently delete your account")
    expect(rendered).to include("Support staff accounts can't be deleted")
  end

  it "shows deletion errors" do
    assign(:deletion_error, "Wrong password, try again.")
    render_for(create_account("Oops"))

    expect(rendered).to include("Wrong password, try again.")
  end
end
