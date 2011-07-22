class ClosetHanger < ActiveRecord::Base
  belongs_to :item
  belongs_to :user

  attr_accessible :owned, :quantity

  validates :item_id, :uniqueness => {:scope => [:user_id, :owned]}
  validates :quantity, :numericality => {:greater_than => 0}
  validates_presence_of :item, :user

  scope :alphabetical_by_item_name, joins(:item).order(Item.arel_table[:name])
  scope :owned_before_wanted, order(arel_table[:owned].desc)

  def verb(subject=:someone)
    base = (owned?) ? 'own' : 'want'
    base + 's' if subject != :you
    base
  end
end

