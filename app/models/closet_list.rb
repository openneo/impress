class ClosetList < ActiveRecord::Base
  belongs_to :user
  has_many :hangers, :class_name => 'ClosetHanger'

  attr_accessible :description, :hangers_owned, :name

  validates :name, :presence => true, :uniqueness => {:scope => :user_id}
  validates :user, :presence => true
  validates :hangers_owned, :inclusion => {:in => [true, false], :message => "can't be blank"}

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

