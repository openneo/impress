class Zone < ActiveRecord::Base
  translates :label, :plain_label
  
  # When selecting zones that an asset occupies, we allow the zone to set
  # whether or not the zone is "sometimes" occupied. This is false by default.
  attr_writer :sometimes
  
  scope :alphabetical, lambda {
    includes_translations.order(Zone::Translation.arel_table[:label])
  }
  scope :includes_translations, lambda { includes(:translations) }
  scope :with_plain_label, lambda { |label|
    t = Zone::Translation.arel_table
    includes(:translations).where(t[:plain_label].eq(Zone.plainify_label(label)))
  }
  
  def uncertain_label
    @sometimes ? "#{label} sometimes" : label
  end
  
  def self.all_plain_labels
    Zone.select([:id]).includes(:translations).all.map(&:plain_label).uniq.sort
  end
  
  def self.plainify_label(label)
    plain_label = label.delete('\- /').downcase
    if plain_label.end_with?('item')
      plain_label = plain_label[0..-5]
    end
    plain_label
  end
end
