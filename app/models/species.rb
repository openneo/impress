class Species < ActiveRecord::Base
  translates :name
  
  scope :alphabetical, lambda { with_translations(I18n.locale).order(Species::Translation.arel_table[:name]) }
  
  def as_json(options={})
    {:id => id, :name => human_name}
  end
  
  def human_name
    name.capitalize
  end
end
