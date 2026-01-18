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

        # Resize the layer to fit the canvas size
        # All layer images are square, but may not be CANVAS_SIZE x CANVAS_SIZE
        # We need to resize them to exactly CANVAS_SIZE x CANVAS_SIZE
        if layer_image.width != CANVAS_SIZE || layer_image.height != CANVAS_SIZE
          layer_image = layer_image.resize(
            CANVAS_SIZE.to_f / layer_image.width,
            vscale: CANVAS_SIZE.to_f / layer_image.height
          )
        end

        # Composite this layer onto the canvas at (0, 0)
        # No offset needed since the layer is now exactly canvas-sized
        canvas = canvas.composite([layer_image], :over)
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
