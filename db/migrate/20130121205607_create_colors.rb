class CreateColors < ActiveRecord::Migration[4.2]
  def self.up
    create_table :colors do |t|
      t.boolean :basic
      t.boolean :standard
    end
    Color.create_translation_table! :name => :string
  end

  def self.down
    drop_table :colors
    Color.drop_translation_table!
  end
end
