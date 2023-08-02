class ItemOutfitRelationship < ApplicationRecord
  belongs_to :item
  belongs_to :outfit
  
  validates_presence_of :item
end
