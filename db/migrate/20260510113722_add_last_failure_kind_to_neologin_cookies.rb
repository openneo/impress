class AddLastFailureKindToNeologinCookies < ActiveRecord::Migration[8.0]
  def change
    add_column :neologin_cookies, :last_failure_kind, :string
  end
end
