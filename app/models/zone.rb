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
  
  n = 0
  @objects = YAML.load_file(Rails.root.join('config', 'zones.yml')).map do |a|
    a['id'] = (n += 1)
    obj = new(a)
    if obj.type_id == 2 || obj.type_id == 3
      zone_name = obj.label.delete(' -').gsub(/item$/, '').downcase
      ItemZoneSets[zone_name] ||= []
      ItemZoneSets[zone_name] << obj
    end
    obj
  end
  n = nil
end
