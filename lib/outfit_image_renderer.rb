require "vips"

class OutfitImageRenderer
  CANVAS_SIZE = 600

  def initialize(outfit)
    @outfit = outfit
  end

  def render
    layers = @outfit.visible_layers

    # Filter out layers without image URLs
    layers_with_images = layers.select(&:image_url?)

    return nil if layers_with_images.empty?

    # Fetch all layer images in parallel
    image_data_by_layer = fetch_layer_images(layers_with_images)

    # Create transparent canvas in sRGB colorspace
    canvas = Vips::Image.black(CANVAS_SIZE, CANVAS_SIZE, bands: 4)
    canvas = canvas.new_from_image([0, 0, 0, 0])
    canvas = canvas.copy(interpretation: :srgb)

    # Composite each layer onto the canvas
    layers_with_images.each do |layer|
      image_data = image_data_by_layer[layer]
      next unless image_data

      begin
        layer_image = Vips::Image.new_from_buffer(image_data, "")

        # Center the layer on the canvas
        x_offset = (CANVAS_SIZE - layer_image.width) / 2
        y_offset = (CANVAS_SIZE - layer_image.height) / 2

        # Composite this layer onto the canvas
        canvas = canvas.composite([layer_image], :over, x: x_offset, y: y_offset)
      rescue Vips::Error => e
        # Log and skip layers that fail to load/composite
        Rails.logger.warn "Failed to composite layer #{layer.id} (#{layer.image_url}): #{e.message}"
        next
      end
    end

    # Return PNG data
    canvas.write_to_buffer(".png")
  end

  private

  def fetch_layer_images(layers)
    image_data_by_layer = {}

    DTIRequests.load_many(max_at_once: 10) do |semaphore|
      layers.each do |layer|
        semaphore.async do
          begin
            response = DTIRequests.get(layer.image_url)
            if response.success?
              image_data_by_layer[layer] = response.read
            else
              Rails.logger.warn "Failed to fetch image for layer #{layer.id} (#{layer.image_url}): HTTP #{response.status}"
            end
          rescue => e
            Rails.logger.warn "Error fetching image for layer #{layer.id} (#{layer.image_url}): #{e.message}"
          end
        end
      end

      image_data_by_layer
    end
  end
end
