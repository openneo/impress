class ItemOutfitRelationship < ApplicationRecord
  belongs_to :item
  belongs_to :outfit, touch: true
  
  validates_presence_of :item
end
