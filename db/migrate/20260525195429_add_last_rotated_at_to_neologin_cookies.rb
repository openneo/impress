class AddLastRotatedAtToNeologinCookies < ActiveRecord::Migration[8.0]
  def change
    add_column :neologin_cookies, :last_rotated_at, :datetime
  end
end
