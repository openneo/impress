require 'carrierwave/processing/mime_types'

class OutfitImageUploader < CarrierWave::Uploader::Base
  include CarrierWave::MimeTypes
  include CarrierWave::MiniMagick
  
  # Settings for S3 storage. Will only be used on production.
  fog_directory 'impress-outfit-images'
  fog_attributes 'Cache-Control' => "max-age=#{15.minutes}",
    'Content-Type' => 'image/png'
  
  process :set_content_type
  
  version :medium do
    process :resize_to_fill => [300, 300]
  end
  
  version :small do
    process :resize_to_fill => [150, 150]
  end
  
  def filename
    "thumb.png"
  end
  
  def store_dir
    partition_id = model.id / 1000
    partition_dir = "%03d" % partition_id
    "outfits/#{partition_dir}/#{model.id}"
  end
  
  def default_url
    "/images/outfits/" + [version_name, "default.png"].compact.join('_')
  end
end
