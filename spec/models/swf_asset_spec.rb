require 'spec_helper'

describe SwfAsset do
  it "belongs to a zone" do
    asset = Factory.create :swf_asset, :zone_id => 1
    asset.zone_id.should == 1
    asset.zone.id.should == 1
    asset.zone.label.should == 'Music'
  end
  
  it "delegates depth to zone" do
    asset = Factory.create :swf_asset, :zone_id => 1
    asset.depth.should == 1
  end
  
  it "converts neopets URL to impress URL" do
    asset = Factory.create :swf_asset, :url => 'http://images.neopets.com/cp/items/swf/000/000/012/12211_9969430b3a.swf'
    asset.local_url.should == 'http://impress.openneo.net/assets/swf/outfit/items/000/000/012/12211_9969430b3a.swf'
  end
  
  it "should contain id, depth, zone ID, and local_url as JSON" do
    asset = Factory.create :swf_asset,
      :id => 123,
      :zone_id => 4,
      :body_id => 234,
      :url => 'http://images.neopets.com/cp/items/swf/000/000/012/12211_9969430b3a.swf'
    asset.as_json.should == {
      :id => 123,
      :depth => 6,
      :body_id => 234,
      :local_url => 'http://impress.openneo.net/assets/swf/outfit/items/000/000/012/12211_9969430b3a.swf',
      :zone_id => 4
    }
  end
end
