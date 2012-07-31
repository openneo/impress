require 'carrierwave/processing/mime_types'

class OutfitImageUploader < CarrierWave::Uploader::Base
  include CarrierWave::MimeTypes
  include CarrierWave::MiniMagick
  
  # Settings for S3 storage. Will only be used on production.
  fog_directory 'openneo-uploads'
  fog_attributes 'Cache-Control' => "max-age=#{15.minutes}",
    'Content-Type' => 'image/png'
  
  process :set_content_type
  
  version :medium do
    process :resize_to_fill => [300, 300]
  end
  
  version :small, :from_version => :medium do
    process :resize_to_fill => [150, 150]
  end
  
  def filename
    "preview.png"
  end
  
  def store_dir
    "outfits/#{partition_dir}"
  end
  
  # 123006789 => "123/006/789"
  def partition_dir
    partitions.map { |partition| "%03d" % partition }.join('/')
  end
  
  # 123006789 => [123, 6, 789]
  def partitions
    [6, 3, 0].map { |n| model.id / 10**n % 1000 }
  end
end
