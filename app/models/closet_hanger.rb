class ClosetHanger < ActiveRecord::Base
  belongs_to :item
  belongs_to :user

  attr_accessible :quantity

  validates :item_id, :uniqueness => {:scope => :user_id}
  validates :quantity, :numericality => {:greater_than => 0}
  validates_presence_of :item, :user

  scope :alphabetical_by_item_name, joins(:item).order(Item.arel_table[:name])
end

