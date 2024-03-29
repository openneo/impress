class ClosetHanger < ApplicationRecord
  belongs_to :item
  belongs_to :list, class_name: 'ClosetList', optional: true
  belongs_to :user

  delegate :name, to: :item, prefix: true

  validates :item_id, :uniqueness => {:scope => [:user_id, :owned, :list_id]}
  validates :quantity, :numericality => {:greater_than => 0}
  validates_presence_of :item, :user

  validate :list_belongs_to_user

  scope :alphabetical_by_item_name, -> {
    it = Item::Translation.arel_table
    joins(:item => :translations).where(it[:locale].eq(I18n.locale)).
      order(it[:name].asc)
  }
  scope :newest, -> { order(arel_table[:created_at].desc) }
  scope :owned_before_wanted, -> { order(arel_table[:owned].desc) }
  scope :unlisted, -> { where(:list_id => nil) }

  {:owned => true, :wanted => false}.each do |name, owned|
    scope "#{name}_trading", -> {
      joins(:user).includes(:list).
        where(:owned => owned).
        where((
          arel_table[:list_id].eq(nil).and(
            User.arel_table["#{name}_closet_hangers_visibility"].gteq(ClosetVisibility[:trading].id)
          )
          ).or(
          ClosetList.arel_table[:visibility].gteq(ClosetVisibility[:trading].id)
        ))
      }
  end

  before_validation :merge_quantities, :set_owned_by_list

  def possibly_null_closet_list
    list || user.null_closet_list(owned)
  end

  def trading?
    possibly_null_closet_list.trading?
  end

  def possibly_null_list_id=(list_id_or_owned)
    if list_id_or_owned.to_s == 'true' || list_id_or_owned.to_s == 'false'
      self.list_id = nil
      self.owned = list_id_or_owned
    else
      self.list_id = list_id_or_owned
      # owned is set in the set_owned_by_list hook
    end
  end

  def verb(subject=:someone)
    self.class.verb(subject, owned?)
  end

  def self.verb(subject, owned, positive=true)
    base = (owned) ? 'own' : 'want'
    base << 's' if positive && subject != :you && subject != :i
    base
  end

  def self.preload_items(
    hangers,
    items_scope: Item.all,
    item_translations_scope: Item::Translation.all
  )
    # Preload the records we need. (This is like `includes`, but `includes`
    # always selects all fields for all records, and we give the caller the
    # opportunity to specify which fields it actually wants via scope!)
    items = items_scope.where(id: hangers.map(&:item_id))
    translations = item_translations_scope.where(item_id: items.map(&:id))

    # Group the records by relevant IDs.
    translations_by_item_id = translations.group_by(&:item_id)
    items_by_id = items.to_h { |i| [i.id, i] }

    # Assign the preloaded records to the records they belong to. (This is like
    # doing e.g. i.translations = ..., but that's a database write - we
    # actually just want to set the `translations` field itself directly!
    # Hacky, ripped from how `ActiveRecord::Associations::Preloader` does it!)
    items.each do |item|
      item.association(:translations).target = translations_by_item_id[item.id]
    end
    hangers.each do |hanger|
      hanger.association(:item).target = items_by_id[hanger.item_id]
    end
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
    
    if quantity > 0
      # If quantity is non-zero, create/update the corresponding hanger.
      
      unless hanger
        hanger = self.new
        hanger.user_id = conditions[:user_id]
        hanger.item_id = conditions[:item_id]
        # One of the following will be nil, and that's okay. If owned is nil,
        # we'll cover for it before validation, as always.
        hanger.owned   = conditions[:owned]
        hanger.list_id = conditions[:list_id]
      end
      
      hanger.quantity = quantity
      hanger.save!
    elsif hanger
      # If quantity is zero and there's a hanger, destroy it.
      hanger.destroy
    end
    
    # If quantity is zero and there's no hanger, good. Do nothing.
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
    # hanger. Select enough for our logic and to update flex_source.
    # TODO: We deleted flex, does this reduce what data we need here?
    conflicting_hanger = self.class.select([:id, :quantity, :user_id, :item_id,
                                            :owned]).
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

