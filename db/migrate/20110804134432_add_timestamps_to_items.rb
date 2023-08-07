class AddTimestampsToItems < ActiveRecord::Migration[3.2]
  def self.up
    add_timestamps :objects

    timestamp_query = "(SELECT created_at FROM contributions WHERE contributed_id = objects.id AND contributed_type = 'Item')"
    update "UPDATE objects SET created_at = #{timestamp_query}, updated_at = #{timestamp_query}"
  end

  def self.down
    remove_timestamps :objects
  end
end

