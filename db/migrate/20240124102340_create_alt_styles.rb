class CreateAltStyles < ActiveRecord::Migration[7.1]
  def change
    create_table :alt_styles do |t|
      t.references :species, type: :integer, null: false, foreign_key: true
      t.references :color, type: :integer, null: false, foreign_key: true
      t.integer :body_id, null: false

      t.timestamps
    end
  end
end
