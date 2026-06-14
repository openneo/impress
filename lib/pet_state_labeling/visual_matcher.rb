module PetStateLabeling
  # Tier 2: infer a pose by image similarity against labeled references of the
  # same species, for assets the structural tier didn't recognize (mostly assets
  # Neopets re-uploaded under a new ID).
  #
  #   - Mood comes from the nearest mouth reference. Moods look very different,
  #     so this is reliable.
  #   - Gender comes from the nearest eyes reference *within that mood*. The
  #     difference is often just eyelashes, so we require the nearest to be close
  #     AND to beat the other gender by a margin. If the two genders are
  #     genuinely tied (a duplicate-asset pet like Robot/Varwolf), we stop trying
  #     to see a difference that isn't there and make the same deterministic
  #     guess the rest of the app uses (PetType#canonical_pet_state).
  #
  # Anything far/ambiguous abstains (returns nil) and stays unlabeled.
  class VisualMatcher
    # All in the units of ImageComparator#distance. Tuned against `validate`.
    MOUTH_MATCH_MAX = 25.0  # nearest mouth must be at least this close
    EYES_MATCH_MAX  = 25.0  # nearest eyes must be at least this close
    GENDER_MARGIN   = 3.0   # winning gender must beat the other by this much
    DUPLICATE_EPS   = 1.5   # below this, two refs are "the same art"

    def initialize(index, comparator: ImageComparator.new)
      @index = index
      @comparator = comparator
      @assets = {}
      @prewarmed_species = Set.new
    end

    # `pet_type` is used only for the duplicate-gender guess. Returns a
    # Prediction (tier "visual" or "visual_guess") or nil (abstain).
    def predict(appearance, species_id:, pet_type:)
      return nil unless appearance.eyes_id && appearance.mouth_id
      prewarm_species(species_id)
      target_eyes = signature_for(appearance.eyes_id)
      target_mouth = signature_for(appearance.mouth_id)
      return nil if target_eyes.nil? || target_mouth.nil?

      evidence = { eyes_asset_id: appearance.eyes_id,
                   mouth_asset_id: appearance.mouth_id }

      # --- Mood, from the nearest mouth reference ---
      mouth_ref, mouth_dist = nearest(target_mouth, @index.mouth_references(species_id))
      return nil if mouth_ref.nil? || mouth_dist > MOUTH_MATCH_MAX
      mood_id = mouth_ref.mood_id
      evidence[:mood_id] = mood_id
      evidence[:mouth_distance] = mouth_dist.round(2)

      # --- Gender, from the nearest eyes reference within that mood ---
      eyes_refs = @index.eyes_references(species_id).select { |r| r.mood_id == mood_id }
      best_fem,  fem_dist  = nearest(target_eyes, eyes_refs.select(&:female))
      best_masc, masc_dist = nearest(target_eyes, eyes_refs.reject(&:female))
      evidence[:fem_distance]  = fem_dist&.round(2)
      evidence[:masc_distance] = masc_dist&.round(2)

      female, tier, confidence = decide_gender(fem_dist, masc_dist, pet_type, evidence)
      return nil if female.nil?

      pose = POSES.find { |p| MOOD_BY_POSE[p] == mood_id && FEMALE_BY_POSE[p] == female }
      Prediction.new(pose:, tier:, confidence:, evidence:)
    end

    private

    # Returns [female?, tier, confidence] or [nil, ...] to abstain.
    def decide_gender(fem_dist, masc_dist, pet_type, evidence)
      nearest_dist = [fem_dist, masc_dist].compact.min
      return [nil, nil, nil] if nearest_dist.nil? || nearest_dist > EYES_MATCH_MAX

      if fem_dist && masc_dist
        if (fem_dist - masc_dist).abs <= DUPLICATE_EPS
          # The two genders are the same art => nothing to see. Guess the way the
          # rest of the app does, and flag it so it's easy to find later. When
          # it's a genuine close duplicate the guess is safe to apply (the art is
          # identical, so the arbitrary gender renders the same either way); a
          # tie between two so-so matches is shakier, so keep it under the floor.
          evidence[:duplicate_gender] = true
          confidence = nearest_dist <= DUPLICATE_EPS ? 0.85 : 0.7
          return [guessed_female(pet_type), "visual_guess", confidence]
        end

        winner_is_fem = fem_dist < masc_dist
        margin = (fem_dist - masc_dist).abs
        return [nil, nil, nil] if margin < GENDER_MARGIN
        [winner_is_fem, "visual", confidence_for_margin(margin)]
      else
        # Only one gender has references for this species+mood. Trust it if it's
        # clearly close, but keep confidence modest.
        [fem_dist ? true : false, "visual", 0.75]
      end
    end

    def confidence_for_margin(margin)
      margin >= 10 ? 0.9 : 0.82
    end

    def guessed_female(pet_type)
      presentation = pet_type.color&.default_gender_presentation ||
        (pet_type.id.even? ? :fem : :masc)
      presentation == :fem
    end

    def nearest(target_sig, refs)
      best = nil
      best_dist = nil
      refs.each do |ref|
        sig = signature_for(ref.asset_id)
        next if sig.nil?
        dist = @comparator.distance(target_sig, sig)
        if best_dist.nil? || dist < best_dist
          best_dist = dist
          best = ref
        end
      end
      [best, best_dist]
    end

    def signature_for(asset_id)
      asset = (@assets[asset_id] ||= SwfAsset.find_by(id: asset_id))
      asset && @comparator.signature(asset)
    end

    # Load and signature all of a species' reference assets in one parallel
    # batch the first time we encounter the species, instead of fetching them
    # one slow image at a time inside `nearest`.
    def prewarm_species(species_id)
      return unless @prewarmed_species.add?(species_id)

      ref_ids = (@index.eyes_references(species_id) +
                 @index.mouth_references(species_id)).map(&:asset_id).uniq
      assets = SwfAsset.where(id: ref_ids).to_a
      assets.each { |asset| @assets[asset.id] = asset }
      @comparator.prewarm(assets)
    end
  end
end
