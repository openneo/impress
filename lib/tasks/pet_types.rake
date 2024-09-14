# This method is designed as a little console helper when labeling new poses
# for a species/color pair. We don't apply it automatically, because it's not
# super reliable? But it can be a time-saver for uncertain manual work!
#
# The logic is: look for the six most recent pet states, then assume their
# Eyes assets' IDs follow the pattern below. It's possible to get uncertain
# results with fewer pet states available, but the gaps in the pattern (for
# Angry, which isn't in most customization) helps us!
EYES_POSE_OFFSETS = { 0 => "Happy Masc", 1 => "Sad Masc", 3 => "Sick Masc",
                      4 => "Happy Fem",  5 => "Sad Fem",  7 => "Sick Fem" }

namespace :pet_types do
    desc "Try to guess poses for color/species where they all look the same"
    task :guess, [:color_name, :species_name] => :environment do |task, args|
        begin
            pt = PetType.matching_name(args.color_name, args.species_name).first!
        rescue ActiveRecord::RecordNotFound
            abort "Could not find pet type for " +
                  "#{args.color_name} #{args.species_name}"
        end

        eyes_id_by_pet_state_id = pt.pet_states.order(id: :desc).limit(6).
            joins(:swf_assets).merge(SwfAsset.where(zone_id: 33)).
            pluck(:id, "swf_assets.remote_id").sort_by { |(k, v)| v }.to_h

        # Only use pet states whose eyes ID is close to the largest eyes ID.
        latest_eyes_id = eyes_id_by_pet_state_id.values.max
        eyes_id_by_pet_state_id.filter! { |k, v| v >= latest_eyes_id - 7 }

        # Convert the eyes IDs into offsets from the lowest one we know of.
        lowest_eyes_id = eyes_id_by_pet_state_id.values.min
        offsets_by_pet_state_id = eyes_id_by_pet_state_id.
        transform_values { |id| id - lowest_eyes_id }

        # Use the gaps in the pattern to help us shift forward if needed. That is,
        # if our first eyes ID isn't actually Happy Masc, we can slide until we
        # find the right starting point in the pattern!
        shifted_offsets_by_pet_state_id = offsets_by_pet_state_id.dup
        shift_success = false
        7.times do |i|
            offsets = shifted_offsets_by_pet_state_id.values
            if !offsets.all? { |o| EYES_POSE_OFFSETS.has_key?(o) }
                shifted_offsets_by_pet_state_id.transform_values! { |v| v + 1 }
            else
                shift_success = true
                break
            end
        end

        unless shift_success
            raise "Couldn't find valid offsets: #{offsets_by_pet_state_id}"
        end

        shifted_offsets_by_pet_state_id.each do |pet_state_id, offset|
            puts "#{pet_state_id}: #{EYES_POSE_OFFSETS.fetch(offset, '??')} (+#{offset})"
        end
    end
end
