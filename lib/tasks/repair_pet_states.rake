namespace :pet_states do
  desc "Sort pet state SWFs, then remove duplicates and reassign children"
  task :repair => :environment do
    PetState.repair_all!
  end
end
