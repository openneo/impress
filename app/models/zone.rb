class Zone < StaticResource
  ATTRIBUTE_NAMES = ['id', 'label', 'depth', 'type_id']
  ZONE_SETS = {}
  
  attr_reader *ATTRIBUTE_NAMES
  # When selecting zones that an asset occupies, we allow the zone to set
  # whether or not the zone is "sometimes" occupied. This is false by default.
  attr_writer :sometimes

  def initialize(attributes)
    ATTRIBUTE_NAMES.each do |name|
      instance_variable_set "@#{name}", attributes[name]
    end
  end
  
  def uncertain_label
    @sometimes ? "#{label} sometimes" : label
  end
  
  def self.find_set(name)
    ZONE_SETS[plain(name)]
  end
  
  def self.plain(name)
    name.delete('\- /').downcase
  end
  
  n = 0
  @objects = YAML.load_file(Rails.root.join('config', 'zones.yml')).map do |a|
    a['id'] = (n += 1)
    obj = new(a)
    plain_name = plain(obj.label)
    
    ZONE_SETS[plain_name] ||= []
    ZONE_SETS[plain_name] << obj
    obj
  end
  n = nil
  
  # Add aliases to keys like "lowerforegrounditem" to "lowerforeground"
  # ...unless there's already such a key, like "backgrounditem" to "background",
  # in which case we don't, because that'd be silly.
  ZONE_SETS.keys.each do |name|
    if name.end_with?('item')
      stripped_name = name[0..-5]
      ZONE_SETS[stripped_name] ||= ZONE_SETS[name]
    end
  end
end
