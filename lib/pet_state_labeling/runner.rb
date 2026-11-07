module PetStateLabeling
  # Runs the labeling pipeline over the unlabeled backlog: structural tier first,
  # then visual for the residual. Applies only predictions at or above
  # `min_confidence`; everything else is left unlabeled (the review queue).
  # Every applied label is recorded to PetStateLabelAudit.
  class Runner
    Outcome = Data.define(:pet_state, :prediction, :applied)

    def initialize(dry_run: true, limit: nil, only_tier: nil, min_confidence: 0.0)
      @dry_run = dry_run
      @limit = limit
      @only_tier = only_tier # nil, "structural", or "visual"
      @min_confidence = min_confidence
      @outcomes = []
      @tally = Hash.new(0)
    end

    attr_reader :outcomes, :tally

    def run
      states = PetState.needs_labeling.newest_pet_type.newest
      states = states.limit(@limit) if @limit
      states = states.to_a
      @tally[:considered] = states.size

      index = AssetIndex.new
      structural = StructuralMatcher.new(index)
      visual = VisualMatcher.new(index)

      appearances = PetStateLabeling.appearances_for(states)
      present = present_poses_for(states)
      mouth_genders = mouth_genders_for(states)
      pet_types = PetType.where(id: states.map(&:pet_type_id).uniq).
        includes(:color).index_by(&:id)

      states.each do |pet_state|
        appearance = appearances[pet_state.id]
        pet_type = pet_types[pet_state.pet_type_id]

        prediction = predict(structural, visual, pet_state, appearance, pet_type, present)
        if prediction.nil?
          @tally[:abstained] += 1
          next
        end
        if prediction.confidence < @min_confidence
          @tally[:below_threshold] += 1
          next
        end

        mouth_key = [pet_state.pet_type_id, appearance&.mouth_id]
        prediction = pair_duplicate_guess(prediction, mouth_genders[mouth_key])
        @tally[:flipped_guess] += 1 if prediction.evidence[:flipped_from]
        mouth_genders[mouth_key] << FEMALE_BY_POSE[prediction.pose] if appearance&.mouth_id

        applied = apply!(pet_state, prediction)
        @tally[:"applied_#{prediction.tier}"] += 1 if applied
        @tally[:applied] += 1 if applied
        @outcomes << Outcome.new(pet_state:, prediction:, applied:)
      end

      self
    end

    private

    def predict(structural, visual, pet_state, appearance, pet_type, present)
      unless @only_tier == "visual"
        prediction = structural.predict(
          appearance, present_poses: present[pet_state.pet_type_id]
        )
        return prediction if prediction
      end

      unless @only_tier == "structural"
        return visual.predict(
          appearance, species_id: pet_type.species_id, pet_type:
        )
      end

      nil
    end

    # A "visual_guess" is an arbitrary gender for art that's identical across
    # genders (e.g. Varwolf). But Neopets still ships those as a fem/masc *pair*
    # of states: same mouth asset, distinct eyes assets. A per-pet-type guess
    # would give both halves the same gender, collapsing them onto one pose and
    # leaving the other empty. So if this state's mouth-sharing sibling already
    # has exactly one known gender, take the other one. (The art is identical,
    # so which half gets which renders the same either way.)
    def pair_duplicate_guess(prediction, sibling_genders)
      return prediction unless prediction.tier == "visual_guess"
      return prediction unless sibling_genders.size == 1

      female = !sibling_genders.first
      return prediction if FEMALE_BY_POSE[prediction.pose] == female

      mood_id = MOOD_BY_POSE[prediction.pose]
      pose = POSES_BY_MOOD[mood_id].find { |p| FEMALE_BY_POSE[p] == female }
      prediction.with(pose:,
        evidence: prediction.evidence.merge(flipped_from: prediction.pose))
    end

    # The genders already labeled on each (pet type, mouth asset) among the
    # targets' pet types, so a duplicate-art guess can pair up with its sibling.
    def mouth_genders_for(states)
      pt_ids = states.map(&:pet_type_id).uniq
      labeled = PetState.usable.where(pet_type_id: pt_ids).to_a
      appearances = PetStateLabeling.appearances_for(labeled)
      genders = Hash.new { |h, k| h[k] = Set.new }
      labeled.each do |ps|
        mouth_id = appearances[ps.id].mouth_id
        genders[[ps.pet_type_id, mouth_id]] << ps.female if mouth_id
      end
      genders
    end

    def apply!(pet_state, prediction)
      return true if @dry_run

      PetState.transaction do
        pet_state.pose = prediction.pose
        pet_state.save!
        PetStateLabelAudit.record!(pet_state, prediction)
      end
      Rails.logger.info "[PetStateLabeling] Labeled pet state " \
        "##{pet_state.id} as #{prediction.pose} via #{prediction.tier} " \
        "(confidence #{prediction.confidence}): #{prediction.evidence.to_json}"
      true
    rescue StandardError => error
      Rails.logger.error "[PetStateLabeling] Failed to label pet state " \
        "##{pet_state.id}: #{error.message}"
      @tally[:errored] += 1
      false
    end

    # The poses already labeled on each target's pet type, for elimination.
    def present_poses_for(states)
      pt_ids = states.map(&:pet_type_id).uniq
      present = Hash.new { |h, k| h[k] = Set.new }
      PetState.usable.where(pet_type_id: pt_ids).
        select(:pet_type_id, :mood_id, :female, :unconverted).
        each { |ps| present[ps.pet_type_id] << ps.pose }
      present
    end
  end
end
