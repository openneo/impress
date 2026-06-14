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
