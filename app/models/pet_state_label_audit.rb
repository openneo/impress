# A record of a label that the automated labeling pipeline applied to a pet
# state (see `lib/pet_state_labeling/`). This is our audit trail: it lets us
# inspect what the pipeline did and why, and revert a batch if needed.
class PetStateLabelAudit < ApplicationRecord
  belongs_to :pet_state

  serialize :evidence, coder: JSON, type: Hash

  scope :recent, -> { order(created_at: :desc) }
  scope :for_tier, ->(tier) { where(tier:) }

  # Capture an applied prediction. The pet state should already be saved with
  # its new label by the time we record this.
  def self.record!(pet_state, prediction)
    create!(
      pet_state:,
      pose: pet_state.pose,
      mood_id: pet_state.mood_id,
      female: pet_state.female,
      tier: prediction.tier,
      confidence: prediction.confidence,
      evidence: prediction.evidence,
      created_at: Time.now,
    )
  end
end
