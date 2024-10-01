require "addressable/template"

class AltStyle < ApplicationRecord
  belongs_to :species
  belongs_to :color

  has_many :parent_swf_asset_relationships, as: :parent
  has_many :swf_assets, through: :parent_swf_asset_relationships
  has_many :contributions, as: :contributed, inverse_of: :contributed

  validates :body_id, presence: true
  validates :series_name, presence: true, allow_nil: true
  validates :thumbnail_url, presence: true

  before_create :infer_series_name
  before_create :infer_thumbnail_url

  scope :matching_name, ->(series_name, color_name, species_name) {
    color = Color.find_by_name!(color_name)
    species = Species.find_by_name!(species_name)
    where(series_name:, color_id: color.id, species_id: species.id)
  }
  scope :by_creation_date, -> {
    order("DATE(created_at) DESC")
  }

  def pet_name
    I18n.translate('pet_types.human_name', color_human_name: color.human_name,
                   species_human_name: species.human_name)
  end

  alias_method :name, :pet_name

  # If the series_name hasn't yet been set manually by support staff, show the
  # string "<New?>" instead. But it won't be searchable by that string—that is,
  # `fits:<New?>-faerie-draik` intentionally will not work, and the canonical
  # filter name will be `fits:alt-style-IDNUMBER`, instead.
  def series_name
    self[:series_name] || "<New?>"
  end

  # You can use this to check whether `series_name` is returning the actual
  # value or its placeholder value.
  def has_real_series_name?
    self[:series_name].present?
  end

  def adjective_name
    "#{series_name} #{color.human_name}"
  end

  def full_name
    "#{series_name} #{name}"
  end

  def preview_image_url
    swf_asset = swf_assets.first
    return nil if swf_asset.nil?

    swf_asset.image_url
  end

  # Given a list of items, return how they look on this alt style.
  def appearances_for(items, ...)
    Item.appearances_for(items, self, ...)
  end

  def biology=(biology)
    # TODO: This is very similar to what `PetState` does, but like… much much
    # more compact? Idk if I'm missing something, or if I was just that much
    # more clueless back when I wrote it, lol 😅
    self.swf_assets = biology.values.map do |asset_data|
      SwfAsset.from_biology_data(self.body_id, asset_data)
    end
  end

  # Until the end of 2024, assume new alt styles are from the "Nostalgic"
  # series. That way, we can stop having to manually label them all as they
  # come out and get modeled (TNT is prolific rn!), but we aren't gonna get too
  # greedy and forget about this and use Nostalgic for some far-future thing,
  # in ways that will certainly be fixable but would also be confusing and
  # embarrassing.
  NOSTALGIC_FINAL_DAY = Date.new(2024, 12, 31)
  def infer_series_name
    if !has_real_series_name? && Date.today <= NOSTALGIC_FINAL_DAY
      self.series_name = "Nostalgic"
    end
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
    if has_real_series_name?
      self.thumbnail_url = THUMBNAIL_URL_TEMPLATE.expand(
        series: series_name.gsub(/\s+/, '').downcase,
        color: color.name.gsub(/\s+/, '').downcase,
        species: species.name.gsub(/\s+/, '').downcase,
      ).to_s
    else
      self.thumbnail_url = DEFAULT_THUMBNAIL_URL
    end
  end

  # For convenience in the console!
  def self.find_by_name(color_name, species_name)
    color = Color.find_by_name(color_name)
    species = Species.find_by_name(species_name)
    where(color_id: color, species_id: species).first
  end
end
