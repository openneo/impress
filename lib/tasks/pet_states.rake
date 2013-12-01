namespace :pet_states do
  desc "Sort pet state SWFs, then remove duplicates and reassign children"
  task :repair => :environment do
    PetState.repair_all!
  end

  desc "Delete the bad pet state, replacing it in outfits with the good pet state"
  task :replace, [:bad_id, :good_id] => :environment do |t, args|
    bad, good = PetState.find(args[:bad_id], args[:good_id])
    outfit_count = bad.replace_with(good)
    puts "Updated #{outfit_count} outfits"
  end
end
