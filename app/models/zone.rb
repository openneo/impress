class Zone < ActiveRecord::Base
  translates :label, :plain_label
  
  # When selecting zones that an asset occupies, we allow the zone to set
  # whether or not the zone is "sometimes" occupied. This is false by default.
  attr_writer :sometimes
  
  scope :alphabetical, lambda {
    with_translations(I18n.locale).order(Zone::Translation.arel_table[:label])
  }
  scope :includes_translations, lambda { includes(:translations) }
  scope :with_plain_label, lambda { |label|
    t = Zone::Translation.arel_table
    includes(:translations).where(t[:plain_label].eq(Zone.plainify_label(label)))
  }
  scope :for_items, lambda { where(arel_table[:type_id].gt(1)) }
  
  def uncertain_label
    @sometimes ? "#{label} sometimes" : label
  end
  
  def self.all_plain_labels
    select([:id]).includes(:translations).all.map(&:plain_label).uniq.sort
  end
  
  def self.plainify_label(label)
    label.delete('\- /').parameterize
  end
end
