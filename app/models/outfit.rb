class Outfit < ActiveRecord::Base
  has_many :item_outfit_relationships
  belongs_to :pet_state
  belongs_to :user
  
  validates :name, :presence => true
  validates :pet_state, :presence => true
  
  attr_accessible :name, :pet_state_id, :starred, :unworn_item_ids, :worn_item_ids
  
  def worn_and_unworn_items
    {:worn => [], :unworn => []}.tap do |output|
      item_outfit_relationships.all(:include => :item).each do |rel|
        key = rel.is_worn? ? :worn : :unworn
        output[key] << rel.item
      end
    end
  end
  
  def worn_item_ids=(item_ids)
    add_relationships(item_ids, true)
  end
  
  def unworn_item_ids=(item_ids)
    add_relationships(item_ids, false)
  end
  
  def add_relationships(item_ids, worn)
    item_ids.each do |item_id|
      rel = ItemOutfitRelationship.new
      rel.item_id = item_id
      rel.is_worn = worn
      item_outfit_relationships << rel
    end
  end
end
