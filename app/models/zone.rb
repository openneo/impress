class Zone < ActiveRecord::Base
  translates :label, :plain_label
  
  # When selecting zones that an asset occupies, we allow the zone to set
  # whether or not the zone is "sometimes" occupied. This is false by default.
  attr_writer :sometimes
  
  scope :alphabetical, -> {
    zt = Zone::Translation.arel_table
    with_translations(I18n.locale).order(zt[:label].asc)
  }
  scope :includes_translations, -> { includes(:translations) }
  scope :matching_label, ->(label, locale = I18n.locale) {
    t = Zone::Translation.arel_table
    joins(:translations)
      .where(t[:locale].eq(locale))
      .where(t[:plain_label].eq(Zone.plainify_label(label)))
  }
  scope :for_items, -> { where(arel_table[:type_id].gt(1)) }

  def uncertain_label
    @sometimes ? "#{label} sometimes" : label
  end
  
  def self.plainify_label(label)
    label.delete('\- /').parameterize
  end
end
