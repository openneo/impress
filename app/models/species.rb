class Species < ActiveRecord::Base
  translates :name
  
  scope :alphabetical, -> { with_translations(I18n.locale).order(Species::Translation.arel_table[:name]) }
  
  def as_json(options={})
    {:id => id, :name => human_name}
  end
  
  def human_name
    if name
      name.capitalize
    else
      I18n.translate('species.default_human_name')
    end
  end
end
