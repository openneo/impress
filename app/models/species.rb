class Species < ApplicationRecord
  translates # TODO: Remove once we're all done with translations!
  has_many :pet_types
  has_many :alt_styles
  
  scope :alphabetical, -> { order(:name) }

  scope :with_body_id, -> body_id {
    pt = PetType.arel_table
    joins(:pet_types).where(pt[:body_id].eq(body_id)).limit(1)
  }

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
