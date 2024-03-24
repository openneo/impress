class IncreaseLimitForItemOutfitRelationshipsId < ActiveRecord::Migration[7.1]
  def change
    reversible do |direction|
      change_table :item_outfit_relationships do |t|
        direction.up { t.change :id, :integer, limit: 8 }
        direction.down{ t.change :id, :integer, limit: 4 }
      end
    end
  end
end
