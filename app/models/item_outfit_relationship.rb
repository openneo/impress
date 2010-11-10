class ItemOutfitRelationship < ActiveRecord::Base
  belongs_to :item
  belongs_to :outfit
  
  validates_presence_of :item
end
