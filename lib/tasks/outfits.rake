namespace :outfits do
  desc 'Retroactively enqueue image updates for outfits saved to user accounts'
  task :retroactively_enqueue => :environment do
    outfits = Outfit.select([:id]).where('image IS NULL AND user_id IS NOT NULL')
    puts "Enqueuing #{outfits.count} outfits"
    outfits.find_each do |outfit|
      Resque.enqueue(OutfitImageUpdate::Retroactive, outfit.id)
    end
    puts "Successfully enqueued."
  end
end
