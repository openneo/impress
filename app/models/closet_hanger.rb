class ClosetHanger < ActiveRecord::Base
  belongs_to :item
  belongs_to :list, :class_name => 'ClosetList'
  belongs_to :user

  attr_accessible :list_id, :owned, :quantity

  validates :item_id, :uniqueness => {:scope => [:user_id, :owned, :list_id]}
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

  before_validation :merge_quantities, :set_owned_by_list

  def verb(subject=:someone)
    self.class.verb(subject, owned?)
  end

  def self.verb(subject, owned, positive=true)
    base = (owned) ? 'own' : 'want'
    base << 's' if positive && subject != :you && subject != :i
    base
  end
  
  def self.set_quantity!(quantity, options)
    quantity = quantity.to_i
    conditions = {:user_id => options[:user_id].to_i,
      :item_id => options[:item_id].to_i}
    
    if options[:key] == "true"
      conditions[:owned] = true
      conditions[:list_id] = nil
    elsif options[:key] == "false"
      conditions[:owned] = false
      conditions[:list_id] = nil
    else
      conditions[:list_id] = options[:key].to_i
    end
    
    hanger = self.where(conditions).first
    unless hanger
      hanger = self.new
      hanger.user_id = conditions[:user_id]
      hanger.item_id = conditions[:item_id]
      # One of the following will be nil, and that's okay. If owned is nil,
      # we'll cover for it before validation, as always.
      hanger.owned   = conditions[:owned]
      hanger.list_id = conditions[:list_id]
    end
    
    unless quantity == 0
      Rails.logger.debug("Logging to #{hanger.id} quantity #{quantity}")
      hanger.quantity = quantity
      hanger.save!
    else
      hanger.destroy if hanger
    end
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
  
  def merge_quantities
    # Find a hanger that conflicts: for the same item, in the same user's
    # closet, same owned status, same list. It also must not be the current
    # hanger.
    conflicting_hanger = self.class.select([:id, :quantity]).
      where(:user_id => user_id, :item_id => item_id, :owned => owned,
        :list_id => list_id).where(['id != ?', self.id]).first
    
    # If there is such a hanger, remove it and merge its quantity into this one.
    if conflicting_hanger
      self.quantity += conflicting_hanger.quantity
      conflicting_hanger.destroy
    end
    
    true
  end

  def set_owned_by_list
    self.owned = list.hangers_owned if list
    true
  end
end

