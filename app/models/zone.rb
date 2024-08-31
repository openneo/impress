class Zone < ActiveRecord::Base
  scope :alphabetical, -> { order(:label) }
  scope :matching_label, ->(label) {
    where(plain_label: Zone.plainify_label(label))
  }
  scope :for_items, -> { where(arel_table[:type_id].gt(1)) }

  def as_json(options={})
    super({only: [:id, :depth, :label]}.merge(options))
  end

  def is_commonly_used_by_items
    # Zone metadata marks item zones with types 2, 3, and 4. But also, in
    # practice, the Biology Effects zone (type 1, ID 4) has been used for a few
    # items too. So, that's what we return true for!
    # TODO: It'd probably be better to make this a database field?
    [2, 3, 4].include?(type_id) || id == 4
  end
  
  def self.plainify_label(label)
    label.delete('\- /').parameterize
  end
end
