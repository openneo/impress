class Color < PetAttribute
  fetch_objects!
  
  Basic = %w(blue green red yellow).map { |name| find_by_name(name) }
  BasicIds = Basic.map(&:id)
  
  def self.basic_ids
    BasicIds
  end
  
  def self.nonstandard_ids
    @nonstandard_ids ||= File.read(Rails.root.join('config', 'nonstandard_colors.txt')).
      chomp.split("\n").map { |name| Color.find_by_name(name).id }
  end
end
