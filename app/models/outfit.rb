class Outfit < ActiveRecord::Base
  has_many :item_outfit_relationships, :dependent => :destroy
  has_many :worn_item_outfit_relationships, :class_name => 'ItemOutfitRelationship',
    :conditions => {:is_worn => true}
  has_many :worn_items, :through => :worn_item_outfit_relationships, :source => :item
  belongs_to :pet_state
  belongs_to :user
  
  validates :name, :presence => true, :uniqueness => {:scope => :user_id}
  validates :pet_state, :presence => true
  
  attr_accessible :name, :pet_state_id, :starred, :worn_and_unworn_item_ids
  
  def as_json(more_options={})
    serializable_hash :only => [:id, :name, :pet_state_id, :starred],
      :methods => [:color_id, :species_id, :worn_and_unworn_item_ids]
  end
  
  def closet_item_ids
    item_outfit_relationships.map(&:item_id)
  end
  
  def color_id
    pet_state.pet_type.color_id
  end
  
  def species_id
    pet_state.pet_type.species_id
  end
  
  def to_query
    {
      :closet => closet_item_ids,
      :color => color_id,
      :objects => worn_item_ids,
      :species => species_id,
      :state => pet_state_id
    }.to_query
  end
  
  def worn_and_unworn_item_ids
    {:worn => [], :unworn => []}.tap do |output|
      item_outfit_relationships.each do |rel|
        key = rel.is_worn? ? :worn : :unworn
        output[key] << rel.item_id
      end
    end
  end
  
  def worn_and_unworn_item_ids=(all_item_ids)
    new_rels = []
    all_item_ids.each do |key, item_ids|
      worn = key == 'worn'
      unless item_ids.blank?
        item_ids.each do |item_id|
          rel = ItemOutfitRelationship.new
          rel.item_id = item_id
          rel.is_worn = worn
          new_rels << rel
        end
      end
    end
    self.item_outfit_relationships = new_rels
  end
  
  def worn_item_ids
    worn_and_unworn_item_ids[:worn]
  end
end
