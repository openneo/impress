# The roulette: spins a random pet, dresses it in a random set of compatible
# items, and lands you in the wardrobe editor wearing them. The .json format
# returns those params as data, plus wardrobe_url and png_url shortcuts to the
# editor page and its rendering. That's handy for testing, too. The .png
# format forwards to that same image endpoint (/outfits/new.png), which does
# the rendering. That endpoint ignores `state` and works out the pet from
# species, color, and pose, so the image can show a different state than the
# one picked here. (And with no pose, it 400s.)
#
# Query params:
#   species=N   Spin only that species (ID or name). Unknown ones are a 400.
#               Its color is usually a standard one, like any other spin.
#   color=N     Spin only that color (ID or name). Unknown ones are a 400.
#   full=1      Dress every zone that can be filled. Falsy values like 0, false,
#               or no turn it off. Can't be combined with count or zones.
#   count=N     Fill exactly N random zones (0 = a bare pet). Can't be combined
#               with full or zones.
#   zones=40,23 Fill only these specific zones (IDs only). Zones that nothing
#               fits are left empty, so the result can be a bare pet. Unknown
#               IDs are a 400, as are the music and sound effects zones, and a
#               list longer than the number of zones that exist.
class RoulettesController < ApplicationController
  def new
    # Every spin is different, so don't let browsers or proxies reuse one.
    expires_now

    query = Roulette.spin(full_outfit: full_outfit?, zone_count:, zones:,
                          species_id:, color_id:)

    respond_to do |format|
      format.html { redirect_to wardrobe_url(**query) }

      # For folks who want the random outfit as data. It's also handy for
      # testing, since we can check the params without following redirects.
      format.json do
        render json: query.merge(wardrobe_url: wardrobe_url(**query),
                                 png_url: wardrobe_url(**query, format: :png))
      end

      # The random outfit as an image, via the editor's own rendering.
      format.png { redirect_to wardrobe_url(**query, format: :png) }
    end
  rescue Roulette::InvalidRequest => error
    # A bad ?species=, ?color=, ?full=, ?count= or ?zones= value.
    respond_to do |format|
      # The message repeats back the caller's input, so it has to be explicitly
      # text/plain. (Inside format.html, `render plain:` stays text/html, and
      # that's a reflected XSS.)
      format.html do
        render plain: error.message, status: :bad_request,
               content_type: "text/plain"
      end
      format.json { render json: {error: error.message}, status: :bad_request }
      format.png do
        render plain: error.message, status: :bad_request,
               content_type: "text/plain"
      end
    end
  end

  private

  TRUTHY_VALUES = %w[1 true yes on].freeze
  FALSY_VALUES = %w[0 false no off].freeze

  # ?full=1: whether to fill every zone. A bare ?full is on; falsy values like
  # 0, false, and no are off. Anything else is a 400, rather than guessing.
  def full_outfit?
    return false unless params.key?(:full)
    return true if params[:full].blank?

    value = params[:full].to_s.downcase
    return true if TRUTHY_VALUES.include?(value)
    return false if FALSY_VALUES.include?(value)

    raise Roulette::InvalidRequest, "full must be 1 or 0, but got: #{params[:full]}"
  end

  # ?count=N: how many random zones to fill (0 is allowed, for a bare pet).
  def zone_count
    return nil if params[:count].blank?

    value = params[:count].to_s
    unless value.match?(/\A\d+\z/)
      raise Roulette::InvalidRequest,
            "count must be a whole number of 0 or more, but got: #{value}"
    end

    value.to_i
  end

  # ?zones=40,23: which zones to fill (IDs). The roulette does all the parsing
  # and checking, so we just pass it along.
  def zones
    params[:zones].presence&.to_s
  end

  # ?species=N or species=name: which species to spin. Like the rest of the
  # site, we accept either an ID or a name.
  def species_id
    return nil if params[:species].blank?

    Species.param_to_id(params[:species].to_s)
  rescue ActiveRecord::RecordNotFound
    raise Roulette::InvalidRequest, "Unknown species: #{params[:species]}"
  end

  # ?color=N or color=name: which color to spin. Like the rest of the site, we
  # accept either an ID or a name.
  def color_id
    return nil if params[:color].blank?

    Color.param_to_id(params[:color].to_s)
  rescue ActiveRecord::RecordNotFound
    raise Roulette::InvalidRequest, "Unknown color: #{params[:color]}"
  end
end
