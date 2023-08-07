class CreateZones < ActiveRecord::Migration[3.2]
  def self.up
    create_table :zones do |t|
      t.integer :depth
      t.integer :type_id
    end
    Zone.create_translation_table! :label => :string, :plain_label => :string
  end

  def self.down
    drop_table :zones
    Zone.drop_translation_table!
  end
end
