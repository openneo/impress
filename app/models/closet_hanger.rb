class ClosetHanger < ActiveRecord::Base
  belongs_to :item
  belongs_to :list, :class_name => 'ClosetList'
  belongs_to :user

  attr_accessible :list_id, :owned, :quantity

  validates :item_id, :uniqueness => {:scope => [:user_id, :owned]}
  validates :quantity, :numericality => {:greater_than => 0}
  validates_presence_of :item, :user

  validate :list_belongs_to_user

  scope :alphabetical_by_item_name, joins(:item).order(Item.arel_table[:name])
  scope :newest, order(arel_table[:created_at].desc)
  scope :owned_before_wanted, order(arel_table[:owned].desc)
  scope :unlisted, where(:list_id => nil)

  {:owned => true, :wanted => false}.each do |name, owned|
    scope "#{name}_trading", joins(:user).includes(:list).
      where(:owned => owned).
      where((
        arel_table[:list_id].eq(nil).and(
          User.arel_table["#{name}_closet_hangers_visibility"].gteq(ClosetVisibility[:trading].id)
        )
        ).or(
        ClosetList.arel_table[:visibility].gteq(ClosetVisibility[:trading].id)
      ))
  end

  before_validation :set_owned_by_list

  def verb(subject=:someone)
    self.class.verb(subject, owned?)
  end

  def self.verb(subject, owned, positive=true)
    base = (owned) ? 'own' : 'want'
    base << 's' if positive && subject != :you && subject != :i
    base
  end

  protected

  def list_belongs_to_user
    if list_id?
      if list
        errors.add(:list_id, "must belong to you") unless list.user_id == user_id
      else
        errors.add(:list, "must exist")
      end
    end
  end

  def set_owned_by_list
    self.owned = list.hangers_owned if list
    true
  end
end

