class Species < ApplicationRecord
  has_many :pet_types
  has_many :alt_styles
  
  scope :alphabetical, -> { order(:name) }
  
  def as_json(options={})
    super({only: [:id, :name], methods: [:human_name]}.merge(options))
  end
  
  def human_name
    if name
      name.capitalize
    else
      I18n.translate('species.default_human_name')
    end
  end

  # Given a list of body IDs, return a hash from body ID to Species.
  # (We assume that each body ID belongs to just one species; if not, which
  # species we return for that body ID is undefined.)
  def self.with_body_ids(body_ids)
    species_ids_by_body_id = PetType.where(body_id: body_ids).distinct.
      pluck(:body_id, :species_id).to_h
    species_by_id = Species.where(id: species_ids_by_body_id.values).
      to_h { |s| [s.id, s] }
    species_ids_by_body_id.transform_values { |id| species_by_id[id] }
  end
end
