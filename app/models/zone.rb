class Zone < StaticResource
  AttributeNames = ['id', 'label', 'depth']
  
  attr_reader *AttributeNames

  def initialize(attributes)
    AttributeNames.each do |name|
      instance_variable_set "@#{name}", attributes[name]
    end
  end
  
  n = 0
  @objects = YAML.load_file(Rails.root.join('config', 'zones.yml')).map do |a|
    a['id'] = (n += 1)
    new(a)
  end
  n = nil
end
