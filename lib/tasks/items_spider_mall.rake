namespace :items do
  desc "Spider NC Mall for wearable items, and store them for later asset spidering"
  task :spider_mall => :environment do
    Item.spider_mall!
  end
end
