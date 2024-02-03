class Species < ApplicationRecord
  has_many :pet_types
  has_many :alt_styles
  
  scope :alphabetical, -> { order(:name) }

  scope :with_body_id, -> body_id {
    pt = PetType.arel_table
    joins(:pet_types).where(pt[:body_id].eq(body_id)).limit(1)
  }
  
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
end
