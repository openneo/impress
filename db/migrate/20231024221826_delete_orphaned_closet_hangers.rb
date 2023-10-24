class DeleteOrphanedClosetHangers < ActiveRecord::Migration[7.0]
  def up
    orphaned_hangers = ClosetHanger.left_outer_joins(:list).
      where("closet_hangers.list_id IS NOT NULL").where("closet_lists.id IS NULL")
    puts orphaned_hangers.to_json
    orphaned_hangers.delete_all
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "The orphaned hangers are already gone!"
  end
end
