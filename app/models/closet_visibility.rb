module ClosetVisibility
  class Level
    attr_accessor :id, :name
    attr_writer :description

    def initialize(data)
      data.each do |key, value|
        send("#{key}=", value)
      end
    end

    def description(subject=nil)
      if subject
        @description.sub('$SUBJECT', subject).capitalize
      else
        @description
      end
    end
  end

  LEVELS = [
    Level.new(
      :id => 0,
      :name => :private,
      :description => "Only you can see $SUBJECT"
    ),
    Level.new(
      :id => 1,
      :name => :public,
      :description => "Anyone who visits this page can see $SUBJECT"
    ),
    Level.new(
      :id => 2,
      :name => :advertised,
      :description => "$SUBJECT will be publicly listed for trades"
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

