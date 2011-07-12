class ClosetHanger < ActiveRecord::Base
  belongs_to :item
  belongs_to :user

  scope :alphabetical_by_item_name, joins(:item).order(Item.arel_table[:name])
end

