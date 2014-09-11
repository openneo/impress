class Campaign < ActiveRecord::Base
  attr_accessible :active, :goal, :progress

  has_many :donations

  def progress_percent
    (progress.to_f / goal) * 100
  end

  def self.current
    self.where(active: true).first or
      raise ActiveRecord::RecordNotFound.new("no current campaign")
  end
end
