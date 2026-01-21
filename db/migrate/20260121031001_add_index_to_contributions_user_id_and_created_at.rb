class AddIndexToContributionsUserIdAndCreatedAt < ActiveRecord::Migration[8.1]
  def change
    add_index :contributions, [:user_id, :created_at],
      name: 'index_contributions_on_user_id_and_created_at'
  end
end
