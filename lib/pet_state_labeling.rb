# Automated labeling of unlabeled pet states.
#
# Labeling a pet state means deciding its *mood* (mood_id: 1=happy/2=sad/4=sick)
# and *gender presentation* (female: true/false), which together form one of
# `PetState::MAIN_POSES`. We normally do this by hand, eyeballing the Eyes and
# Mouth assets. This module infers it instead, in two tiers:
#
#   1. StructuralMatcher — exact matching on asset IDs against our existing
#      labeled data. Eyes asset => pose (mood+gender), mouth asset => mood.
#      High precision; this is the only reliable source of *gender* (Neopets
#      gives fem/masc distinct asset IDs even when the art is identical).
#
#   2. VisualMatcher — image similarity (ruby-vips) for the residual, mainly to
#      catch assets Neopets re-uploaded under a new ID. Mood is easy visually;
#      gender uses nearest same-species reference with a distance+margin gate,
#      and a deterministic guess for true duplicate-asset pets (Robot/Varwolf).
#
# The Runner applies only confident predictions and leaves the rest unlabeled
# (unlabeled *is* the review queue), recording every write to PetStateLabelAudit.
module PetStateLabeling
  # Biology zones that carry the mood/gender signal (see Zone table).
  EYES_ZONE_ID = 33
  MOUTH_ZONE_ID = 34

  # The six poses we label, and their decomposition into mood + gender. (Mirrors
  # the mapping baked into `PetState#pose`/`#pose=`.)
  POSES = PetState::MAIN_POSES
  MOOD_BY_POSE = {
    "HAPPY_MASC" => 1, "HAPPY_FEM" => 1,
    "SAD_MASC" => 2, "SAD_FEM" => 2,
    "SICK_MASC" => 4, "SICK_FEM" => 4,
  }.freeze
  FEMALE_BY_POSE = POSES.to_h { |p| [p, p.end_with?("_FEM")] }.freeze
  POSES_BY_MOOD = POSES.group_by { |p| MOOD_BY_POSE[p] }.freeze

  # A prediction produced by a matcher. `tier` is "structural", "visual", or
  # "visual_guess"; `evidence` is a Hash describing how we decided (for the
  # audit log). Abstaining is represented by returning `nil` instead.
  Prediction = Data.define(:pose, :tier, :confidence, :evidence)

  # The eyes/mouth asset ids of a pet state.
  Appearance = Data.define(:eyes_id, :mouth_id)

  # Resolve the eyes/mouth asset ids for many pet states in a single query
  # (their assets may be novel and absent from any AssetIndex), returning
  # `{ pet_state_id => Appearance }`. States missing eyes/mouth get nil ids.
  def self.appearances_for(pet_states)
    all_asset_ids = pet_states.flat_map(&:swf_asset_ids).uniq
    zone_of = SwfAsset.biology_assets.
      where(id: all_asset_ids, zone_id: [EYES_ZONE_ID, MOUTH_ZONE_ID]).
      pluck(:id, :zone_id).to_h

    pet_states.to_h do |ps|
      ids = ps.swf_asset_ids
      [ps.id, Appearance.new(
        eyes_id: ids.find { |id| zone_of[id] == EYES_ZONE_ID },
        mouth_id: ids.find { |id| zone_of[id] == MOUTH_ZONE_ID },
      )]
    end
  end
end
