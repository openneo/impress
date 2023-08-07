class CreateWardrobeTips < ActiveRecord::Migration[3.2]
  def up
    create_table :wardrobe_tips do |t|
      t.integer :index, null: false
      t.timestamps
    end
    WardrobeTip.create_translation_table! body: :text
  end

  def down
    drop_table :wardrobe_tips
    WardrobeTip.drop_translation_table!
  end
end
