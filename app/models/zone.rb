class Zone < ActiveRecord::Base  
  # When selecting zones that an asset occupies, we allow the zone to set
  # whether or not the zone is "sometimes" occupied. This is false by default.
  attr_writer :sometimes
  
  scope :alphabetical, -> { order(:label) }
  scope :matching_label, ->(label) {
    where(plain_label: Zone.plainify_label(label))
  }
  scope :for_items, -> { where(arel_table[:type_id].gt(1)) }

  def as_json(options={})
    super({only: [:id, :depth, :label]}.merge(options))
  end

  def uncertain_label
    @sometimes ? "#{label} sometimes" : label
  end
  
  def self.plainify_label(label)
    label.delete('\- /').parameterize
  end
end
