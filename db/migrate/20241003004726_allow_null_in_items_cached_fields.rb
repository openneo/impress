class AllowNullInItemsCachedFields < ActiveRecord::Migration[7.2]
  def change
    # This is a bit more compatible with ActiveRecord's `serialize` utility,
    # which seems pretty insistent that empty arrays should be saved as `NULL`,
    # rather than the empty string our serializer would return if called :(
    change_column_null :items, :cached_compatible_body_ids, true
    change_column_null :items, :cached_occupied_zone_ids, true
  end
end
