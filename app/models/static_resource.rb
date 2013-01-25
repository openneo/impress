class StaticResource
  attr_accessor :id, :name
  
  def self.all
    @objects
  end
  
  def self.find(id_or_ids)
    if id_or_ids.is_a?(Array)
      id_or_ids.uniq.map { |id| find_one(id) }
    else
      find_one(id_or_ids)
    end
  end
  
  def self.count
    @objects.size
  end
  
  private
  
  def self.find_one(id)
    @objects[id - 1]
  end
end
