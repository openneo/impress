class Species < ApplicationRecord
  translates :name
  has_many :pet_types
  
  scope :alphabetical, -> {
    st = Species::Translation.arel_table
    with_translations(I18n.locale).order(st[:name].asc)
  }

  scope :matching_name, ->(name, locale = I18n.locale) {
    st = Species::Translation.arel_table
    joins(:translations).where(st[:locale].eq(locale)).
      where(st[:name].matches(sanitize_sql_like(name)))
  }

  scope :with_body_id, -> body_id {
    pt = PetType.arel_table
    joins(:pet_types).where(pt[:body_id].eq(body_id)).limit(1)
  }

  # TODO: Should we consider replacing this at call sites? This used to be
  # built into the globalize gem but isn't anymore!
  def self.find_by_name(name)
    matching_name(name).first
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
