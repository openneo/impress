class Color < ApplicationRecord
  translates # TODO: Remove once we're all done with translations!
  has_many :pet_types
  
  scope :alphabetical, -> { order(:name) }
  scope :basic, -> { where(basic: true) }
  scope :standard, -> { where(standard: true) }
  scope :nonstandard, -> { where(standard: false) }
  scope :funny, -> { order(:prank) unless pranks_funny? }

  validates :name, presence: true

  # Temporary writer to keep the English translation record updated, while
  # primarily using the attribute on the model itself.
  #
  # Once this app and DTI 2020 are both comfortably off the translation system,
  # we can remove this!
  def name=(new_name)
    globalize.write(:en, :name, new_name)
    write_attribute(:name, new_name)
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
