# Applies what we load from the Rainbow Pool (see Neopets::RainbowPool) to our
# colors and pet types.
#
# The Rainbow Pool lists every color by ID, and for each species, every color
# it can be, with a "basic" image hash we use as the pet type's thumbnail. Its
# Brushes page lists every paint brush, by color ID.
#
# - New colors: we create them, using the Rainbow Pool's name for them (which
#   is usually right, but not always: it calls Elderlygirl "ElderlyGir"!), and
#   fill in paint brush info on existing colors that don't have it yet.
# - New pet types: the listing doesn't include body IDs, so we can't create
#   them directly. Instead we model them: Neopets' CustomPets API accepts an
#   image hash in place of a pet name ("@abc123"), and hands back the same data
#   it does for a real pet, including the body ID and biology layers.
#
# New colors get `standard: false` and `basic: false`. Those are judgment calls
# (does this color share bodies with the basic colors?), so we ping Discord for
# a human to double-check. `false` is the safer guess: item prediction only
# considers nonstandard colors when looking for special bodies, and a color
# that turns out to share basic bodies gets filtered out there anyway.
class PetType::RainbowPoolImport
  # This runs every 10 minutes, so we don't need to catch up all at once, and
  # we'd rather not send Neopets a burst of requests when a color drops for
  # every species.
  MAX_TO_MODEL_PER_RUN = 20

  # When a pet type fails to model, wait this long before trying it again, so
  # one broken entry doesn't cost a request (and a Sentry event) every run.
  # This is best-effort: it relies on `Rails.cache` persisting between runs.
  RETRY_FAILURES_AFTER = 1.day

  # Some warnings need a human to act, and would otherwise repeat every run.
  # Send those to Sentry at most this often. (Also best-effort.)
  REPEAT_WARNINGS_AFTER = 1.day

  SENTRY_TAGS = { task: "neopets:import:rainbow_pool" }.freeze

  Result = Struct.new(:updated_pet_types, :modeled_pet_types, :new_colors,
    :updated_colors, keyword_init: true)

  # `colors_by_species_id` is `{species_id => [{color_id:, name:, image_hash:}]}`,
  # as from `Neopets::RainbowPool.load_colors_for_species`. `species` and
  # `colors` are as from `Neopets::RainbowPool.load_all_pets`, and `brushes` as
  # from `.load_brushes`. Any of them can be missing entries, if they failed to
  # load; we'll just work with what we have.
  def initialize(colors_by_species_id, species: [], colors: [], brushes: [],
      max_to_model: MAX_TO_MODEL_PER_RUN, log: ->(message) { puts message })
    @colors_by_species_id = colors_by_species_id
    @listed_species = species
    @listed_colors = colors
    @brushes_by_color_id = brushes.group_by { |b| b[:color_id] }
    @max_to_model = max_to_model
    @log = log
  end

  def run!
    @result = Result.new(updated_pet_types: [], modeled_pet_types: [],
      new_colors: [], updated_colors: [])

    check_species
    import_colors
    missing = update_known_pet_types
    model_missing_pet_types(missing)

    @result
  ensure
    # Even if something went wrong partway, tell Discord about the colors we
    # did create. (One message, rather than a burst of them.)
    DiscordNotifier.notify_new_colors(@result.new_colors) if @result&.new_colors&.any?
  end

  # Log a warning, and send it to Sentry if we haven't in a while.
  def self.warn_occasionally(message, key:, log: ->(m) { puts m }, **sentry_context)
    log.call "⚠️  #{message}"
    cache_key = ["rainbow_pool_import/warned", key]
    return if Rails.cache.exist?(cache_key)

    Sentry.capture_message(message, level: :warning, tags: SENTRY_TAGS,
      contexts: sentry_context)
    Rails.cache.write(cache_key, true, expires_in: REPEAT_WARNINGS_AFTER)
  end

  # Error messages can come from anywhere (e.g. raw AMF responses), so make
  # sure they're valid UTF-8 before we put them in our own strings.
  def self.safe_message(error)
    error.message.dup.force_encoding(Encoding::UTF_8).scrub
  end

  private

  def warn_occasionally(message, key:, **sentry_context)
    self.class.warn_occasionally(message, key:, log: @log, **sentry_context)
  end

  # We don't create species automatically (they're rare, and a big deal!), but
  # we want to hear about new ones, and about ones that seem to have vanished.
  def check_species
    return if @listed_species.empty?

    listed_ids = @listed_species.map { |s| s[:id] }.to_set
    known_ids = Species.pluck(:id).to_set

    @listed_species.reject { |s| known_ids.include?(s[:id]) }.each do |species|
      warn_occasionally "The Rainbow Pool lists a species we don't have: " +
        "#{species[:name]} (##{species[:id]})",
        key: ["unknown_species", species[:id]], species:
    end

    Species.where.not(id: listed_ids).each do |species|
      warn_occasionally "The Rainbow Pool doesn't list a species we have: " +
        "#{species.human_name} (##{species.id})",
        key: ["unlisted_species", species.id],
        species: { id: species.id, name: species.name }
    end
  end

  def import_colors
    @colors_by_id = Color.all.index_by(&:id)

    names_by_color_id = @listed_colors.to_h { |c| [c[:id], c[:name]] }
    @colors_by_species_id.each_value do |entries|
      entries.each { |e| names_by_color_id[e[:color_id]] ||= e[:name] }
    end

    names_by_color_id.each do |color_id, name|
      color = @colors_by_id[color_id]
      brush = brush_for(color_id, name, existing_pb_item_name: color&.pb_item_name)
      if color.nil?
        create_color!(color_id, name, brush)
      elsif brush
        fill_in_brush_info!(color, brush)
      end
    end
  end

  def create_color!(color_id, name, brush)
    color = Color.new(id: color_id, name: name.downcase, basic: false,
      standard: false, pb_item_name: brush&.dig(:name),
      pb_item_thumbnail_url: brush&.dig(:image_url))

    # Names are unique in practice (we look colors up by name in URLs), so if
    # this one's taken, leave it for a human rather than create a duplicate.
    if Color.where(name: color.name).exists?
      warn_occasionally "Not creating color ##{color_id} #{name.inspect}: " +
        "we already have a color by that name, with a different ID",
        key: ["color_name_conflict", color_id], color: { id: color_id, name: }
      return
    end

    color.save!
    @colors_by_id[color.id] = color
    @result.new_colors << color
    @log.call "🎨 Created new color: #{color.human_name} (##{color.id})"
  end

  # Fill in paint brush info, but don't overwrite anything a human set.
  def fill_in_brush_info!(color, brush)
    color.pb_item_name = brush[:name] if color.pb_item_name.blank?
    if color.pb_item_thumbnail_url.blank?
      color.pb_item_thumbnail_url = brush[:image_url]
    end
    return unless color.changed?

    color.save!
    @result.updated_colors << color
    @log.call "Filled in paint brush info for #{color.human_name}: " +
      "#{color.pb_item_name.inspect}"
  end

  # Some colors have more than one paint brush, like "Blue Paint Brush" and
  # "Starter Blue Paint Brush". Prefer the one we already know about, then the
  # one named after the color, then the oldest. (Others are named differently,
  # like "Royal Paint Brush" for Royalboy, which is why we don't name colors
  # after their brushes.)
  def brush_for(color_id, color_name, existing_pb_item_name: nil)
    brushes = @brushes_by_color_id[color_id]
    return nil if brushes.blank?

    preferred_names = [existing_pb_item_name, "#{color_name} Paint Brush"].compact
    preferred_names.each do |preferred_name|
      brush = brushes.find { |b| b[:name].casecmp?(preferred_name) }
      return brush if brush
    end
    brushes.min_by { |b| b[:item_id] }
  end

  # Apply image hashes to the pet types we already have, and return the
  # entries we don't have yet.
  def update_known_pet_types
    pet_types_by_key = PetType.all.index_by { |pt| [pt.species_id, pt.color_id] }
    missing = []

    Species.order(:name).each do |species|
      entries = @colors_by_species_id[species.id]
      next if entries.nil?

      changed_pet_types = []
      entries.each do |entry|
        pet_type = pet_types_by_key[[species.id, entry[:color_id]]]
        if pet_type.nil?
          missing << entry.merge(species:)
        elsif apply_image_hash(pet_type, entry[:image_hash])
          changed_pet_types << pet_type
        end
      end

      PetType.transaction { changed_pet_types.each(&:save!) }
      @result.updated_pet_types.concat(changed_pet_types)
      @log.call "#{species.human_name}: #{entries.size} colors listed, " +
        "#{changed_pet_types.size} image hashes saved"
    end

    missing
  end

  def model_missing_pet_types(entries)
    return if entries.empty?
    @log.call "Found #{entries.size} pet types we don't have yet"

    # Skip ones that failed recently. And shuffle the rest, so that if some
    # fail every time, they can't crowd out the others under our limit.
    entries = entries.reject { |e| Rails.cache.exist?(failure_cache_key(e)) }
    entries = entries.shuffle

    if entries.size > @max_to_model
      @log.call "Modeling #{@max_to_model} of the #{entries.size} we can " +
        "try right now, which is our limit per run; the rest will wait"
    end

    entries.first(@max_to_model).each do |entry|
      model_pet_type(entry)
    rescue Pet::ModelingDisabled
      @log.call "Modeling is disabled, so skipping new pet types"
      break
    end
  end

  def model_pet_type(entry)
    species = entry[:species]
    label = "#{entry[:name]} #{species.human_name} " +
      "(color ##{entry[:color_id]}, @#{entry[:image_hash]})"
    @log.call "Modeling new pet type: #{label}"

    pet = Pet.load("@#{entry[:image_hash]}")
    pet_type = pet.pet_type

    if pet_type.species_id != species.id || pet_type.color_id != entry[:color_id]
      raise SkippedEntry, "its image is for species ##{pet_type.species_id} " +
        "and color ##{pet_type.color_id} instead"
    end

    apply_image_hash(pet_type, entry[:image_hash])
    pet.save!
    @result.modeled_pet_types << pet_type
  rescue Pet::ModelingDisabled
    raise
  rescue SkippedEntry => error
    # (We only try this every RETRY_FAILURES_AFTER, so it's already throttled.)
    @log.call "⚠️  Skipping #{label}: #{error.message}"
    Sentry.capture_message("Rainbow Pool image doesn't match its listing",
      level: :warning, tags: SENTRY_TAGS, contexts: { pet_type: { label: } })
    remember_failure(entry)
  rescue => error
    @log.call "⚠️  Failed to model #{label}, skipping: " +
      self.class.safe_message(error)
    Sentry.capture_exception(error, tags: SENTRY_TAGS,
      contexts: { pet_type: { label: } })
    remember_failure(entry)
  end

  # Returns whether the hash changed.
  def apply_image_hash(pet_type, image_hash)
    return false if pet_type.basic_image_hash == image_hash

    @log.call "#{pet_type.basic_image_hash.nil? ? "Found new" : "Updating"} " +
      "image hash: #{image_hash} (#{pet_type.human_name})"
    pet_type.basic_image_hash = image_hash
    true
  end

  def remember_failure(entry)
    Rails.cache.write(failure_cache_key(entry), true,
      expires_in: RETRY_FAILURES_AFTER)
  end

  def failure_cache_key(entry)
    ["rainbow_pool_import/failed", entry[:species].id, entry[:image_hash]]
  end

  class SkippedEntry < StandardError; end
end
