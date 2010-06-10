class StaticResource
  attr_accessor :id, :name
  
  def self.all
    @objects
  end
  
  def self.find(id)
    @objects[id-1]
  end
end
