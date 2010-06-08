class Color < PetAttribute
  fetch_objects!
  
  Basic = %w(blue green red yellow).map { |name| find_by_name(name) }
  BasicIds = Basic.map(&:id)
end
