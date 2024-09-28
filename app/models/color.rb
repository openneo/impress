class Color < ApplicationRecord
  has_many :pet_types
  
  scope :alphabetical, -> { order(:name) }
  scope :basic, -> { where(basic: true) }
  scope :standard, -> { where(standard: true) }
  scope :nonstandard, -> { where(standard: false) }

  validates :name, presence: true
  
  def as_json(options={})
    {id: id, name: name, human_name: human_name}
  end

  def human_name
    if name
      name.split(' ').map { |word| word.capitalize }.join(' ')
    else
      I18n.translate('colors.default_human_name')
    end
  end

  def example_pet_type(preferred_species: nil)
    preferred_species ||= Species.first
    pet_types.order([Arel.sql("species_id = ? DESC"), preferred_species.id],
      "species_id ASC").first
  end

  def default_gender_presentation
    if name.downcase.ends_with? "boy"
      :masc
    elsif name.downcase.ends_with? "girl"
      :fem
    else
      nil
    end
  end
end
