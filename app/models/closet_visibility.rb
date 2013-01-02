module ClosetVisibility
  class Level
    attr_accessor :id, :name
    attr_writer :description

    def initialize(data)
      data.each do |key, value|
        send("#{key}=", value)
      end
    end

    def description(subject=:items)
      I18n.translate "closet_hangers.visibility.#{name}.description.#{subject}"
    end

    def human_name
      I18n.translate "closet_hangers.visibility.#{name}.name"
    end
  end

  LEVELS = [
    Level.new(
      :id => 0,
      :name => :private
    ),
    Level.new(
      :id => 1,
      :name => :public
    ),
    Level.new(
      :id => 2,
      :name => :trading
    )
  ]

  LEVELS_BY_NAME = {}.tap do |levels_by_name|
    LEVELS.each do |level|
      levels_by_name[level.id] = level
      levels_by_name[level.name] = level
    end
  end

  def self.[](id)
    LEVELS_BY_NAME[id]
  end

  def self.levels
    LEVELS
  end
end

