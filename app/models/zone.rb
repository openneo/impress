class Zone < StaticResource
  AttributeNames = ['id', 'label', 'depth', 'type_id']
  ItemZoneSets = {}
  
  attr_reader *AttributeNames
  # When selecting zones that an asset occupies, we allow the zone to set
  # whether or not the zone is "sometimes" occupied. This is false by default.
  attr_writer :sometimes

  def initialize(attributes)
    AttributeNames.each do |name|
      instance_variable_set "@#{name}", attributes[name]
    end
  end
  
  def uncertain_label
    @sometimes ? "#{label} sometimes" : label
  end
  
  def self.find_set(name)
    ItemZoneSets[plain(name)]
  end
  
  def self.plain(name)
    name.delete('\- /').downcase
  end
  
  n = 0
  @objects = YAML.load_file(Rails.root.join('config', 'zones.yml')).map do |a|
    a['id'] = (n += 1)
    obj = new(a)
    if obj.type_id == 2 || obj.type_id == 3
      plain_name = plain(obj.label)
      
      ItemZoneSets[plain_name] ||= []
      ItemZoneSets[plain_name] << obj
    end
    obj
  end
  n = nil
  
  # Add aliases to keys like "lowerforegrounditem" to "lowerforeground"
  # ...unless there's already such a key, like "backgrounditem" to "background",
  # in which case we don't, because that'd be silly.
  ItemZoneSets.keys.each do |name|
    if name.end_with?('item')
      stripped_name = name[0..-5]
      ItemZoneSets[stripped_name] ||= ItemZoneSets[name]
    end
  end
end
