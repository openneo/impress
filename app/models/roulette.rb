# The roulette. It picks a random pet, and then dresses it in a random set of
# compatible items. The result is a query string the wardrobe editor understands,
# so spinning it lands you in the editor wearing your random outfit.
#
# It loads everything it needs in a handful of small queries, and does all the
# random picking in memory with bitmasks.
class Roulette
  # Raised when the caller asks for something we can't spin, like an unknown
  # species or zone. The message is safe to show to the user.
  class InvalidRequest < ArgumentError; end

  # The fraction of spins that use a basic (standard color) pet type. The rest
  # can be any special-color pet.
  BASIC_PET_CHANCE = 0.8

  # Items in these zones are never worn, because they'd make a random outfit
  # play sound. (Zone 1 is "Music" and zone 2 is "Sound Effects".)
  EXCLUDED_ZONE_IDS = [1, 2].freeze
  EXCLUDED_ZONE_MASK = EXCLUDED_ZONE_IDS.sum { |id| 1 << (id - 1) }

  # How many items to dress a random pet in: a normal distribution centered on
  # 6, so most spins wear about five to seven. That keeps the pet looking
  # properly dressed without filling every zone that has a fitting item. The
  # center and spread are a tuning choice, not measured data. (Each weight is
  # the bell curve's height at that count, scaled so the peak is 1000.)
  ITEM_COUNT_MEAN = 6
  ITEM_COUNT_SPREAD = 1.5
  ITEM_COUNT_WEIGHTS = (3..10).to_h do |count|
    height = Math.exp(-((count - ITEM_COUNT_MEAN)**2) / (2 * ITEM_COUNT_SPREAD**2))
    [count, (1000 * height).round]
  end.freeze

  # Return a hash of wardrobe query params for a random pet, e.g.:
  #   {color: 8, species: 1, pose: "HAPPY_FEM", state: 123, objects: [456, ...]}
  # By default the pet gets a realistic number of items. `full_outfit:` dresses
  # every zone that can be filled, and `zone_count:`/`zones:` choose how many
  # (or which) zones to fill instead; the three are mutually exclusive.
  # `species_id:`/`color_id:` narrow the pet down to a specific species and/or
  # color. Unknown IDs raise InvalidRequest.
  #
  # `rng:` only controls the item picks and the basic/special roll. The pet type
  # comes from MySQL's RAND() and the pet state from an unseeded shuffle, so a
  # seeded spin isn't fully reproducible.
  def self.spin(rng: Random.new, full_outfit: false, zone_count: nil, zones: nil,
                species_id: nil, color_id: nil)
    pet_type = pick_pet_type(species_id:, color_id:, basic: rng.rand < BASIC_PET_CHANCE)

    query = {
      color: pet_type.color_id,
      species: pet_type.species_id,
    }

    if pet_state = pick_pet_state(pet_type.id)
      query[:pose] = pet_state.pose
      query[:state] = pet_state.id
    end

    if item_ids = pick_item_ids(pet_type.body_id, rng:, full_outfit:, zone_count:, zones:)
      query[:objects] = item_ids
    end

    query
  end

  # Pick a random pet type from the given color pool, falling back to the
  # other pool if it has nothing showable. If `color_id:` is given, we look only
  # at that color (and `species_id:`, if given too), with no pool roll. If only
  # `species_id:` is given, the pool roll still applies, so you usually get a
  # standard color. Unknown IDs raise InvalidRequest, as does a species and
  # color with no showable pet type. We use MySQL's RAND() rather than OFFSET
  # rand(count), because our tables are too big for the latter to be quick.
  def self.pick_pet_type(species_id: nil, color_id: nil, basic:)
    # Validate the IDs first, so we can tell "unknown" from "known but
    # unshowable".
    if species_id && !Species.exists?(id: species_id)
      raise InvalidRequest, "Unknown species: #{species_id}"
    end

    if color_id && !Color.exists?(id: color_id)
      raise InvalidRequest, "Unknown color: #{color_id}"
    end

    if color_id
      scope = showable_pet_types(nil, species_id:, color_id:)
      return scope.order(Arel.sql("RAND()")).first ||
        raise(InvalidRequest, no_such_pet_message(species_id, color_id))
    end

    pools = [basic, !basic].map { |pool_basic| showable_pet_types(pool_basic, species_id:) }

    pet_type = pools[0].order(Arel.sql("RAND()")).first ||
      pools[1].order(Arel.sql("RAND()")).first
    return pet_type if pet_type

    raise InvalidRequest, no_such_pet_message(species_id, nil) if species_id
    raise "Roulette couldn't find a pet type with any states!"
  end

  # All the pet types in the given color pool that could be shown (or all of
  # them if `basic` is nil): they have a known color and species (the editor
  # needs both) and at least one state. `species_id:`/`color_id:` narrow it
  # down further. A few old colors have a NULL `basic` flag; like the rest of
  # the site, we treat those as non-basic.
  def self.showable_pet_types(basic, species_id: nil, color_id: nil)
    scope = PetType.joins(:color, :species).where(id: PetState.select(:pet_type_id))

    if basic.nil?
      # Any pool, because the caller asked for a specific species or color.
    elsif basic
      scope = scope.where(colors: {basic: true})
    else
      scope = scope.where(Arel.sql("colors.basic IS NULL OR colors.basic != 1"))
    end

    scope = scope.where(species: {id: species_id}) if species_id
    scope = scope.where(colors: {id: color_id}) if color_id

    scope
  end

  # The error message for a species and/or color that has no showable pet type.
  def self.no_such_pet_message(species_id, color_id)
    kind = [
      ("species #{species_id}" if species_id),
      ("color #{color_id}" if color_id),
    ].compact.join(" and ")

    "No showable pet found for #{kind}"
  end

  private_class_method :showable_pet_types, :no_such_pet_message

  # Pick a random state for the pet, preferring ones someone has validated:
  # labeled and not glitched. If we have none of those, fall back to whatever
  # states exist at all. States with moods we no longer use are skipped in both
  # paths, since the editor would reject them. We only load the columns that
  # determine the pose, because the full row includes a big list of asset IDs.
  def self.pick_pet_state(pet_type_id)
    columns = [:id, :pet_type_id, :mood_id, :female, :unconverted]
    scope = PetState.where(pet_type_id:).select(*columns)

    scope.merge(PetState.usable).to_a.shuffle.find { |state| showable_pose?(state) } ||
      scope.to_a.shuffle.find { |state| showable_pose?(state) }
  end

  # Whether the editor can display this state. `PetState#pose` raises for
  # states with moods we no longer use, so those are off-limits. (A state with
  # no mood or gender yet is fine: its pose is "UNKNOWN", which the editor
  # accepts.)
  def self.showable_pose?(state)
    state.unconverted? || state.mood_id.nil? || [1, 2, 4].include?(state.mood_id)
  end

  private_class_method :showable_pose?

  # Pick how many items to dress the pet in, following the bell curve in
  # ITEM_COUNT_WEIGHTS.
  def self.pick_item_count(rng)
    roll = rng.rand(ITEM_COUNT_WEIGHTS.values.sum)

    ITEM_COUNT_WEIGHTS.each do |count, weight|
      return count if roll < weight

      roll -= weight
    end
  end

  # Pick a random set of items that all fit the given body and don't conflict
  # with each other. Two items conflict if one occupies a zone the other
  # occupies or restricts, which is how the editor decides it, with one
  # difference: we read an item's zones from `cached_occupied_zone_ids`, which
  # covers every body it fits, while the editor checks the zones on this
  # specific body (`findItemConflicts`). So we can be stricter than the editor,
  # and `zones:` can pick an item that only occupies that zone on other bodies,
  # so it may not show on this pet. (Per-body zones would need a join against
  # `swf_assets`.)
  #
  # By default we stop at a realistic item count; `full_outfit:` fills every
  # zone that can be filled, `zone_count:` fills that many random zones, and
  # `zones:` (a list of IDs, or a comma-separated string) fills only those
  # zones, leaving any that nothing fits empty. The three are mutually
  # exclusive. Unknown zone IDs, and the music and sound effects zones, raise
  # InvalidRequest.
  def self.pick_item_ids(body_id, rng: Random.new, full_outfit: false,
                         zone_count: nil, zones: nil)
    # Each dress-level knob picks a different outfit, so they can't be mixed.
    if full_outfit && (zone_count || !zones.blank?)
      raise InvalidRequest, "full can't be combined with count or zones"
    end

    if zone_count && !zones.blank?
      raise InvalidRequest, "count can't be combined with zones"
    end

    requested = requested_zones(zones)

    # One query gets us everything we need for every item that fits this body:
    # its ID, the zones it restricts (a bit string), and the zones its assets
    # occupy (IDs, cached on the item).
    rows = Item.fits(body_id).pluck(
      :id, :zones_restrict, "cached_occupied_zone_ids"
    )

    # Convert each item into bitmasks of the zones it occupies and restricts
    # (zone N is bit N-1), then group items by each zone they occupy, so we
    # can pick one random item per zone. (An item is in the pool of every zone
    # it occupies, so items that cover several zones get picked more often.
    # That's fine, and means dresses show up a lot.)
    pools = Hash.new { |h, k| h[k] = [] }
    rows.each do |id, zones_restrict, occupied_zone_ids|
      occupied = zone_mask(occupied_zone_ids)
      next if occupied.zero? # Not wearable (e.g. a style token).
      next unless (occupied & EXCLUDED_ZONE_MASK).zero? # Music and sound effects.

      candidate = [id, occupied, restrict_mask(zones_restrict)]
      each_set_zone(occupied) { |zone_id| pools[zone_id] << candidate }
    end

    # Which zones to fill, and how many items to stop at. If the caller chose
    # the zones, those are the only ones we look at (in the order given), and
    # any that nothing fits stay empty. Otherwise it's every zone in random
    # order, and we stop at every zone for a full outfit, or at the requested
    # count, or our default realistic count.
    #
    # An item is compatible if it occupies no zone that's already occupied or
    # restricted, and doesn't restrict a zone that's already occupied.
    # Shuffling each pool before we scan it keeps the picking random without
    # ever looping forever.
    if requested.any?
      zone_order = requested & pools.keys
      target = nil
    else
      zone_order = pools.keys.shuffle(random: rng)
      target = if full_outfit
        nil # Dress every zone that can be filled.
      elsif zone_count
        zone_count # (0 is a bare pet.)
      else
        pick_item_count(rng) # The default realistic count.
      end
    end

    chosen = []
    used_occupied = 0
    used_restricted = 0

    zone_order.each do |zone_id|
      break if target && chosen.size >= target

      compatible = pools[zone_id].shuffle(random: rng).find do |_, occupied, restricted|
        (occupied & used_occupied).zero? &&
          (occupied & used_restricted).zero? &&
          (restricted & used_occupied).zero?
      end

      next if compatible.nil? # This zone is blocked by what we've chosen.

      chosen << compatible[0]
      used_occupied |= compatible[1]
      used_restricted |= compatible[2]
    end

    # Sort for stable URLs, and return nil (not []) if we found nothing.
    chosen.sort.presence
  end

  # The zones a caller asked to fill, as IDs without duplicates, in the order
  # given. `zones` is a list or a comma-separated string. Unknown IDs, junk that
  # isn't an ID at all, a list longer than the number of zones that exist, and
  # the excluded music and sound effects zones all raise InvalidRequest. (Zones
  # with no fitting item are just skipped, not errors.)
  def self.requested_zones(zones)
    return [] if zones.blank?

    raw = zones.is_a?(String) ? zones.split(",", -1) : Array(zones)

    zone_total = Zone.count
    if raw.size > zone_total
      raise InvalidRequest, "Too many zones: only #{zone_total} exist"
    end

    ids = raw.map do |zone|
      unless zone.to_s.match?(/\A\d+\z/)
        raise InvalidRequest, "Unknown zone: #{zone}"
      end

      zone.to_s.to_i
    end.uniq

    if (excluded = ids & EXCLUDED_ZONE_IDS).any?
      raise InvalidRequest, "Zone #{excluded.first} can't be requested, because " +
        "music and sound effects are never worn"
    end

    unknown = (ids - Zone.where(id: ids).pluck(:id)).first
    raise InvalidRequest, "Unknown zone: #{unknown}" if unknown

    ids
  end

  # Build a bitmask from a list of zone IDs (e.g. an item's cached occupied
  # zones). Accepts either the raw CSV string or a loaded array, since pluck's
  # handling of serialized columns varies by Rails version.
  def self.zone_mask(zone_ids)
    ids = zone_ids.is_a?(Array) ? zone_ids : zone_ids.to_s.split(",").map(&:to_i)
    mask = 0
    ids.each { |id| mask |= 1 << (id - 1) if id.positive? }
    mask
  end

  # Build a bitmask from an item's zones_restrict bit string, where the (N-1)th
  # character is a "1" if zone N is restricted. (Some old items have shorter
  # strings; missing characters are just "0".) Most items restrict nothing, so
  # skip the scan for those.
  def self.restrict_mask(zones_restrict)
    return 0 if zones_restrict.blank? || !zones_restrict.include?("1")

    mask = 0
    zones_restrict.each_char.with_index do |bit, index|
      mask |= 1 << index if bit == "1"
    end
    mask
  end

  # Yield each zone ID whose bit is set in the given mask. (Only the set bits,
  # which items have just a few of.) A lone bit's `bit_length` is its zone ID.
  def self.each_set_zone(mask)
    while mask.positive?
      yield (mask & -mask).bit_length
      mask &= mask - 1 # Clear the lowest set bit.
    end
  end

  private_class_method :requested_zones, :zone_mask, :restrict_mask, :each_set_zone
end
