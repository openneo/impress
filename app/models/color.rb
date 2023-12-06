class Color < ApplicationRecord
  translates :name
  has_many :pet_types
  
  scope :alphabetical, -> {
    ct = Color::Translation.arel_table
    with_translations(I18n.locale).order(ct[:name].asc)
  }
  scope :basic, -> { where(:basic => true) }
  scope :standard, -> { where(:standard => true) }
  scope :nonstandard, -> { where(:standard => false) }
  scope :funny, -> { order(:prank) unless pranks_funny? }
  scope :matching_name, ->(name, locale = I18n.locale) {
    ct = Color::Translation.arel_table
    joins(:translations).where(ct[:locale].eq(locale)).
      where(ct[:name].matches(sanitize_sql_like(name)))
  }

  validates :name, presence: true

  # TODO: Should we consider replacing this at call sites? This used to be
  # built into the globalize gem but isn't anymore!
  def self.find_by_name(name)
    matching_name(name).first
  end
  
  def as_json(options={})
    {id: id, name: name, human_name: human_name}
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
    now = Time.now.in_time_zone('Pacific Time (US & Canada)')
    now.month == 4 && now.day == 1
  end
end
