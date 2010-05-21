class PetState < ActiveRecord::Base
  include SwfAssetParent
  SwfAssetType = 'biology'
end
