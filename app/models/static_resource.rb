class StaticResource
  attr_accessor :id, :name
  
  def self.all
    @objects
  end
  
  def self.find(id)
    @objects[id-1]
  end
  
  def self.count
    @objects.size
  end
end
