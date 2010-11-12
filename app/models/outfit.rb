class Outfit < ActiveRecord::Base
  has_many :item_outfit_relationships, :dependent => :destroy
  belongs_to :pet_state
  belongs_to :user
  
  validates :name, :presence => true
  validates :pet_state, :presence => true
  
  attr_accessible :name, :pet_state_id, :starred, :unworn_item_ids, :worn_item_ids
  
  def as_json(more_options={})
    serializable_hash :only => [:id, :name, :pet_state_id, :starred],
      :methods => [:color_id, :species_id, :worn_and_unworn_item_ids]
  end
  
  def color_id
    pet_state.pet_type.color_id
  end
  
  def species_id
    pet_state.pet_type.species_id
  end
  
  def worn_and_unworn_item_ids
    {:worn => [], :unworn => []}.tap do |output|
      item_outfit_relationships.each do |rel|
        key = rel.is_worn? ? :worn : :unworn
        output[key] << rel.item_id
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
