class Color < ActiveRecord::Base
  translates :name
  
  scope :alphabetical, lambda { with_translations(I18n.locale).order(Color::Translation.arel_table[:name]) }
  scope :basic, where(:basic => true)
  scope :standard, where(:standard => true)
  scope :nonstandard, where(:standard => false)
  scope :funny, lambda { order(:prank) unless pranks_funny? }

  validates :name, presence: true
  
  def as_json(options={})
    {id: id, name: human_name, unfunny_name: unfunny_human_name, prank: prank?}
  end

  def human_name
    if prank? && !Color.pranks_funny?
      unfunny_human_name + ' ' + I18n.translate('colors.prank_suffix')
    else
      unfunny_human_name
    end
  end

  def unfunny_human_name
    if name
      name.split(' ').map { |word| word.capitalize }.join(' ')
    else
      I18n.translate('colors.default_human_name')
    end
  end

  def self.pranks_funny?
    today = Date.today
    today.month == 4 && today.day == 1
  end
end
