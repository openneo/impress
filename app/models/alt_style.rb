require "addressable/template"

class AltStyle < ApplicationRecord
  belongs_to :species
  belongs_to :color

  has_many :parent_swf_asset_relationships, as: :parent, dependent: :destroy
  has_many :swf_assets, through: :parent_swf_asset_relationships
  has_many :contributions, as: :contributed, inverse_of: :contributed

  validates :body_id, presence: true
  validates :full_name, presence: true, allow_nil: true
  validates :series_name, presence: true, allow_nil: true
  validates :thumbnail_url, presence: true

  before_validation :infer_thumbnail_url, unless: :thumbnail_url?

  fallback_for(:full_name) { "#{series_name} #{pet_name}" }
  fallback_for(:series_name) { AltStyle.placeholder_name }

  scope :matching_name, ->(series_name, color_name, species_name) {
    color = Color.find_by_name!(color_name)
    species = Species.find_by_name!(species_name)
    where(series_name:, color_id: color.id, species_id: species.id)
  }
  scope :by_creation_date, -> {
    # HACK: Setting up named time zones in MySQL takes effort, so we assume
    #       it's not Daylight Savings. This will produce slightly incorrect
    #       sorting when it *is* Daylight Savings, and records happen to be
    #       created around midnight.
    order(Arel.sql("DATE(CONVERT_TZ(created_at, '+00:00', '-08:00')) DESC"))
  }
  scope :by_series_main_name, -> {
    # The main part of the series name, like "Nostalgic".
    # If there's no colon, uses the whole string.
    order(Arel.sql("SUBSTRING_INDEX(series_name, ': ', -1)"))
  }
  scope :by_series_variant_name, -> {
    # The variant part of the series name, like "Prismatic Cyan".
    # If there's no colon, uses an empty string.
    order(Arel.sql("SUBSTRING(series_name, 1, LOCATE(': ', series_name) - 1)"))
  }
  scope :by_color_name, -> {
    joins(:color).order(Color.arel_table[:name])
  }
  scope :by_name_grouped, -> {
    # Sort by the color name, then the main part of the series name, then the
    # variant part of the series name. This way, all the, say, Christmas colors
    # and their Prismatic variants will be together, including both Festive and
    # Nostalgic cases.
    by_color_name.by_series_main_name.by_series_variant_name
  }
  scope :unlabeled, -> { where(series_name: nil) }
  scope :newest, -> { order(created_at: :desc) }

  def pet_name
    I18n.translate('pet_types.human_name', color_human_name: color.human_name,
                   species_human_name: species.human_name)
  end

  alias_method :name, :pet_name

  def series_main_name
    series_name.split(': ').last
  end

  def series_variant_name
    series_name.split(': ').first
  end

  # Returns the full name, with the species removed from the end (if present).
  def adjective_name
    full_name.sub(/\s+#{Regexp.escape(species.name)}\Z/i, "")
  end

  EMPTY_IMAGE_URL = "data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw=="
  def preview_image_url
    # Use the image URL for the first asset. Or, fall back to an empty image.
    swf_assets.first&.image_url || EMPTY_IMAGE_URL
  end

  # Given a list of items, return how they look on this alt style.
  def appearances_for(items, ...)
    Item.appearances_for(items, self, ...)
  end

  # At time of writing, most batches of Alt Styles thumbnails used a simple
  # pattern for the item thumbnail URL, but that's not always the case anymore.
  # For now, let's keep using this format as the default value when creating a
  # new Alt Style, but the database field can be manually overridden as needed!
  THUMBNAIL_URL_TEMPLATE = Addressable::Template.new(
    "https://images.neopets.com/items/{series}_{color}_{species}.gif"
  )
  DEFAULT_THUMBNAIL_URL = "https://images.neopets.com/items/mall_bg_circle.gif"
  def infer_thumbnail_url
    if real_series_name?
      self.thumbnail_url = THUMBNAIL_URL_TEMPLATE.expand(
        series: series_name.gsub(/\s+/, '').downcase,
        color: color.name.gsub(/\s+/, '').downcase,
        species: species.name.gsub(/\s+/, '').downcase,
      ).to_s
    else
      self.thumbnail_url = DEFAULT_THUMBNAIL_URL
    end
  end

  def real_thumbnail_url?
    thumbnail_url != DEFAULT_THUMBNAIL_URL
  end

  def self.placeholder_name
    "<New?>"
  end

  def self.all_series_names
    distinct.where.not(series_name: nil).
      by_series_main_name.by_series_variant_name.
      pluck(:series_name)
  end

  def self.all_supported_colors
    Color.find(distinct.pluck(:color_id))
  end

  def self.all_supported_species
    Species.find(distinct.pluck(:species_id))
  end

  # For convenience in the console!
  def self.find_by_name(color_name, species_name)
    color = Color.find_by_name(color_name)
    species = Species.find_by_name(species_name)
    where(color_id: color, species_id: species).first
  end
end
