class ClosetList < ActiveRecord::Base
  belongs_to :user
  has_many :hangers, :class_name => 'ClosetHanger', :foreign_key => 'list_id'
  # Nullification of associated records occurs in the ClosetListObserver.

  attr_accessible :description, :hangers_owned, :name, :visibility

  validates :name, :presence => true, :uniqueness => {:scope => :user_id}
  validates :user, :presence => true
  validates :hangers_owned, :inclusion => {:in => [true, false], :message => "can't be blank"}

  scope :alphabetical, order(:name)
  scope :public, where(arel_table[:visibility].gteq(ClosetVisibility[:public].id))
  scope :visible_to, lambda { |user|
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
