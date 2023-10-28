class ClosetList < ApplicationRecord
  belongs_to :user
  has_many :hangers, class_name: 'ClosetHanger', foreign_key: 'list_id', dependent: :destroy

  validates :name, :presence => true, :uniqueness => {:scope => :user_id}
  validates :user, :presence => true
  validates :hangers_owned, :inclusion => {:in => [true, false], :message => "can't be blank"}

  scope :alphabetical, -> { order(:name) }
  scope :publicly_visible, -> {
    where(arel_table[:visibility].gteq(ClosetVisibility[:public].id))
  }
  scope :visible_to, ->(user) {
    condition = arel_table[:visibility].gteq(ClosetVisibility[:public].id)
    condition = condition.or(arel_table[:user_id].eq(user.id)) if user
    where(condition)
  }

  after_save :sync_hangers_owned!

  def sync_hangers_owned!
    if hangers_owned_changed?
      hangers.each do |hanger|
        hanger.owned = hangers_owned
        hanger.save!
      end
    end
  end

  def try_non_null(method_name)
    send(method_name)
  end

  def self.preload_items(
    lists,
    hangers_scope: ClosetHanger.all,
    items_scope: Item.all,
    item_translations_scope: Item::Translation.all
  )
    # Preload the records we need. (This is like `includes`, but `includes`
    # always selects all fields for all records, and we give the caller the
    # opportunity to specify which fields it actually wants via scope!)
    hangers = hangers_scope.where(list_id: lists.map(&:id))

    # Group the records by relevant IDs.
    hangers_by_list_id = hangers.group_by(&:list_id)

    # Assign the preloaded records to the records they belong to. (This is like
    # doing e.g. i.translations = ..., but that's a database write - we
    # actually just want to set the `translations` field itself directly!
    # Hacky, ripped from how `ActiveRecord::Associations::Preloader` does it!)
    lists.each do |list|
      list.association(:hangers).target = hangers_by_list_id[list.id]
    end

    # Then, do similar preloading for the hangers and their items.
    ClosetHanger.preload_items(
      hangers,
      items_scope: items_scope,
      item_translations_scope: item_translations_scope,
    )
  end

  module VisibilityMethods
    delegate :trading?, to: :visibility_level

    def visibility_level
      ClosetVisibility.levels[visibility]
    end

    def trading_changed?
      return false unless visibility_changed?
      level_change = visibility_change.map { |v| ClosetVisibility.levels[v] }
      old_trading, new_trading = level_change.map(&:trading?)
      old_trading != new_trading
    end
  end

  include VisibilityMethods

  class Null
    include VisibilityMethods
    attr_reader :user

    def initialize(user)
      @user = user
    end

    def hangers
      user.closet_hangers.unlisted.where(owned: hangers_owned)
    end

    def hangers_owned?
      hangers_owned
    end

    def try_non_null(method_name)
      nil
    end
  end

  class NullOwned < Null
    def hangers_owned
      true
    end

    def visibility
      user.owned_closet_hangers_visibility
    end

    def visibility_changed?
      user.owned_closet_hangers_visibility_changed?
    end

    def visibility_change
      user.owned_closet_hangers_visibility_change
    end
  end

  class NullWanted < Null
    def hangers_owned
      false
    end

    def visibility
      user.wanted_closet_hangers_visibility
    end

    def visibility_changed?
      user.wanted_closet_hangers_visibility_changed?
    end

    def visibility_change
      user.wanted_closet_hangers_visibility_change
    end
  end
end
