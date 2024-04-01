class IncreaseUsernameLength < ActiveRecord::Migration[7.1]
  def change
    # NOTE: This is paired with a migration to the `openneo_id` database, too!
    reversible do |direction|
      direction.up {
        change_column :users, :name, :string, limit: 30, null: false
      }
      direction.down {
        change_column :users, :name, :string, limit: 20, null: false
      }
    end
  end
end
