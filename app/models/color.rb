class Color < ActiveRecord::Base
  translates :name
  
  scope :alphabetical, lambda { with_translations(I18n.locale).order(Color::Translation.arel_table[:name]) }
  scope :basic, where(:basic => true)
  scope :standard, where(:standard => true)
  scope :nonstandard, where(:standard => false)
  
  def as_json(options={})
    {:id => id, :name => human_name}
  end
  
  def human_name
    if name
      name.split(' ').map { |word| word.capitalize }.join(' ')
    else
      I18n.translate('colors.default_human_name')
    end
  end
end
