class ClosetList < ActiveRecord::Base
  belongs_to :user
  has_many :hangers, :class_name => 'ClosetHanger', :foreign_key => 'list_id',
    :dependent => :nullify

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
end

