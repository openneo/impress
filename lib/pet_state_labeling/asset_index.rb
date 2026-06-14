module PetStateLabeling
  # Builds the lookups the matchers need from a set of labeled pet states
  # (defaults to all `PetState.usable`). Built once per run and reused.
  #
  # For hold-out validation we build an index from just the training split, so
  # this deliberately takes the source states as an argument.
  class AssetIndex
    # A labeled reference for the visual tier: which asset, and what it means.
    Reference = Data.define(:asset_id, :pose, :mood_id, :female)

    def initialize(states: nil)
      @states = states || PetState.usable.to_a
      build!
    end

    # asset_id => { pose => count }. Eyes encode both mood and gender.
    def eyes_poses(asset_id) = @eyes_poses[asset_id] || {}

    # asset_id => { mood_id => count }. Mouth encodes mood, shared across gender.
    def mouth_moods(asset_id) = @mouth_moods[asset_id] || {}

    # Labeled eyes references for one species (across all its colors), for the
    # visual gender comparison.
    def eyes_references(species_id) = @eyes_refs[species_id] || []

    # Labeled mouth references for one species, for the visual mood comparison.
    def mouth_references(species_id) = @mouth_refs[species_id] || []

    # The zone (33/34) of an asset id, if we indexed it; else nil.
    def zone_of(asset_id) = @zone_of[asset_id]

    private

    def build!
      @eyes_poses = Hash.new { |h, k| h[k] = Hash.new(0) }
      @mouth_moods = Hash.new { |h, k| h[k] = Hash.new(0) }
      @eyes_refs = Hash.new { |h, k| h[k] = [] }
      @mouth_refs = Hash.new { |h, k| h[k] = [] }

      # Map every asset id used by these states to its zone, keeping only the
      # eyes/mouth biology assets we care about.
      all_asset_ids = @states.flat_map(&:swf_asset_ids).uniq
      @zone_of = SwfAsset.biology_assets.
        where(id: all_asset_ids, zone_id: [EYES_ZONE_ID, MOUTH_ZONE_ID]).
        pluck(:id, :zone_id).to_h

      # Resolve species_id per state without N+1 queries.
      species_by_pt = PetType.where(id: @states.map(&:pet_type_id).uniq).
        pluck(:id, :species_id).to_h

      @states.each do |ps|
        pose = ps.pose
        eyes_id = asset_in_zone(ps, EYES_ZONE_ID)
        mouth_id = asset_in_zone(ps, MOUTH_ZONE_ID)
        species_id = species_by_pt[ps.pet_type_id]

        if eyes_id
          @eyes_poses[eyes_id][pose] += 1
          @eyes_refs[species_id] << reference(eyes_id, ps)
        end
        if mouth_id
          @mouth_moods[mouth_id][ps.mood_id] += 1
          @mouth_refs[species_id] << reference(mouth_id, ps)
        end
      end

      # De-dup references so each asset appears once per species (the same asset
      # is reused across many states/colors).
      @eyes_refs.each_value { |refs| refs.uniq!(&:asset_id) }
      @mouth_refs.each_value { |refs| refs.uniq!(&:asset_id) }
    end

    def asset_in_zone(pet_state, zone_id)
      pet_state.swf_asset_ids.find { |id| @zone_of[id] == zone_id }
    end

    def reference(asset_id, pet_state)
      Reference.new(asset_id:, pose: pet_state.pose,
        mood_id: pet_state.mood_id, female: pet_state.female)
    end
  end
end
