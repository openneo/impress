class Campaign < ActiveRecord::Base
  has_many :donations

  def progress_percent
    [(progress.to_f / goal) * 100, 100].min
  end

  def remaining
    goal - progress
  end

  def complete?
    progress >= goal
  end

  def self.current
    self.where(active: true).first or
      raise ActiveRecord::RecordNotFound.new("no current campaign")
  end
end
