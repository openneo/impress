class CreateNeologinCookies < ActiveRecord::Migration[8.0]
  def change
    create_table :neologin_cookies do |t|
      t.text :cookie, null: false
      t.references :created_by, type: :integer,
        foreign_key: { to_table: :users }, null: true
      t.datetime :last_used_successfully_at
      t.datetime :last_failed_at
      t.text :last_failure_message
      t.datetime :notified_failure_at
      t.timestamps
    end
  end
end
