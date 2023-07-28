class Species < ActiveRecord::Base
  translates :name
  
  scope :alphabetical, -> { with_translations(I18n.locale).order(Species::Translation.arel_table[:name]) }

  scope :matching_name, ->(name, locale = I18n.locale) {
    st = Species::Translation.arel_table
    joins(:translations).where(st[:locale].eq(locale)).
      where(st[:name].matches(sanitize_sql_like(name)))
  }
  
  def as_json(options={})
    {:id => id, :name => human_name}
  end
  
  def human_name
    if name
      name.capitalize
    else
      I18n.translate('species.default_human_name')
    end
  end

  # TODO: Copied from modern Rails source, can delete once we're there!
  def self.sanitize_sql_like(string, escape_character = "\\")
    pattern = Regexp.union(escape_character, "%", "_")
    string.gsub(pattern) { |x| [escape_character, x].join }
  end
end
