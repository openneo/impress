class Zone < ActiveRecord::Base
  translates # TODO: Remove once we're all done with translations!
  
  # When selecting zones that an asset occupies, we allow the zone to set
  # whether or not the zone is "sometimes" occupied. This is false by default.
  attr_writer :sometimes
  
  scope :alphabetical, -> { order(:label) }
  scope :matching_label, ->(label) {
    where(plain_label: Zone.plainify_label(label))
  }
  scope :for_items, -> { where(arel_table[:type_id].gt(1)) }

  # Temporary writer to keep the English translation record updated, while
  # primarily using the attribute on the model itself.
  #
  # Once this app and DTI 2020 are both comfortably off the translation system,
  # we can remove this!
  def label=(new_label)
    globalize.write(:en, :label, new_label)
    write_attribute(:label, new_label)
  end

  # Temporary writer to keep the English translation record updated, while
  # primarily using the attribute on the model itself.
  #
  # Once this app and DTI 2020 are both comfortably off the translation system,
  # we can remove this!
  def plain_label=(new_plain_label)
    globalize.write(:en, :plain_label, new_plain_label)
    write_attribute(:plain_label, new_plain_label)
  end

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
