class Color < ActiveRecord::Base
  translates :name
  
  scope :alphabetical, lambda { includes(:translations).order(Color::Translation.arel_table[:name]) }
  scope :basic, where(:basic => true)
  scope :standard, where(:standard => true)
  scope :nonstandard, where(:standard => false)
  
  def as_json(options={})
    {:id => id, :name => human_name}
  end
  
  def human_name
    name.split(' ').map { |word| word.capitalize }.join(' ')
  end
end
