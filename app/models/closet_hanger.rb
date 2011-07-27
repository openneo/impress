class ClosetHanger < ActiveRecord::Base
  belongs_to :item
  belongs_to :list, :class_name => 'ClosetList'
  belongs_to :user

  attr_accessible :owned, :quantity

  validates :item_id, :uniqueness => {:scope => [:user_id, :owned]}
  validates :quantity, :numericality => {:greater_than => 0}
  validates_presence_of :item, :user

  scope :alphabetical_by_item_name, joins(:item).order(Item.arel_table[:name])
  scope :owned_before_wanted, order(arel_table[:owned].desc)

  before_validation :set_owned_by_list

  def set_owned_by_list
    self.owned = list.hangers_owned if list?
  end

  def verb(subject=:someone)
    self.class.verb(subject, owned?)
  end

  def self.verb(subject, owned, positive=true)
    base = (owned) ? 'own' : 'want'
    base << 's' if positive && subject != :you && subject != :i
    base
  end
end

