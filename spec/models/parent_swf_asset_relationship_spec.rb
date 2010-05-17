require 'spec_helper'

describe ParentSwfAssetRelationship do
  context "a relationship" do
    before(:each) do
      @relationship = ParentSwfAssetRelationship.new
      Factory.create :item, :name => 'foo'
      @relationship.parent_id = 1
    end
    
    specify "should belong to an swf_asset" do
      Factory.create :swf_asset, :type => 'object', :id => 1
      @relationship.swf_asset_id = 1
      @relationship.swf_asset.id.should == 1
      @relationship.swf_asset.type.should == 'object'
    end
  end
end
