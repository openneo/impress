module PetStateLabeling
  # Tier 1: infer a pose by exact asset-ID matching against labeled data.
  #
  # We treat each available signal as a *constraint* narrowing the set of
  # possible poses, then intersect them:
  #
  #   - eyes asset  -> the pose(s) that asset has been labeled as (mood+gender)
  #   - mouth asset -> the mood(s) that asset has been labeled as -> those poses
  #   - elimination -> the pose must be one not already present in the pet type
  #
  # If the intersection lands on exactly one pose, we predict it. If it's empty
  # the signals *conflict* (a likely re-used asset or an existing mislabel), so
  # we abstain. This is high precision and is our only trustworthy source of
  # gender.
  class StructuralMatcher
    def initialize(index)
      @index = index
    end

    # `appearance` is a PetStateLabeling::Appearance. `present_poses` is the set
    # of poses already labeled on this state's pet type (for elimination); pass
    # nil to skip that signal. Returns a Prediction or nil (abstain).
    def predict(appearance, present_poses: nil)
      evidence = {}

      # Positive signals (eyes/mouth) are the trustworthy ones: eyes encode
      # gender, mouth encodes mood. We resolve the pose from these first.
      positive = []

      if appearance.eyes_id
        poses = @index.eyes_poses(appearance.eyes_id)
        unless poses.empty?
          positive << poses.keys.to_set
          evidence[:eyes_asset_id] = appearance.eyes_id
          evidence[:eyes_poses] = poses
        end
      end

      if appearance.mouth_id
        moods = @index.mouth_moods(appearance.mouth_id)
        unless moods.empty?
          positive << moods.keys.flat_map { |m| POSES_BY_MOOD[m] }.to_set
          evidence[:mouth_asset_id] = appearance.mouth_id
          evidence[:mouth_moods] = moods
        end
      end

      positive_candidates = positive.reduce(:&)

      # Conflicting positive signals (e.g. a re-used asset, or an existing
      # mislabel) => abstain rather than guess.
      return nil if positive_candidates && positive_candidates.empty?

      # Elimination is a weak signal: it assumes this state is one of the poses
      # the pet type doesn't have yet, which breaks when a pet type has two
      # states of the same pose. So we only ever use it to *narrow* positive
      # candidates, never to decide gender on its own.
      candidates = positive_candidates
      used_elimination = false
      if present_poses && (candidates.nil? || candidates.size > 1)
        missing = POSES.to_set - present_poses
        evidence[:eliminated_to] = missing.to_a
        candidates = candidates ? (candidates & missing) : missing
        used_elimination = true
      end

      return nil if candidates.nil? || candidates.size != 1
      pose = candidates.first
      evidence[:candidates] = [pose]

      Prediction.new(pose:, tier: "structural",
        confidence: confidence_for(evidence, positive_candidates, used_elimination),
        evidence:)
    end

    private

    # Grade by how the *gender* got pinned, since that's where structural errors
    # come from. Pinned by a positive signal (eyes) => high; resting on
    # elimination => low (the runner applies a precision floor).
    def confidence_for(evidence, positive_candidates, used_elimination)
      pinned_by_positive = positive_candidates&.size == 1
      if pinned_by_positive && evidence[:eyes_poses]&.size == 1
        0.98 # a single labeled pose for this exact eyes asset
      elsif pinned_by_positive
        0.96 # eyes gender + mouth mood agreed on one pose
      elsif used_elimination && evidence[:eyes_poses]
        0.85 # eyes gave gender, elimination only narrowed mood
      elsif used_elimination && evidence[:mouth_moods]
        0.8 # mouth gave mood, but gender rests on elimination — shakier
      else
        0.7 # elimination did all the work — weakest (often a guess on real data)
      end
    end
  end
end
