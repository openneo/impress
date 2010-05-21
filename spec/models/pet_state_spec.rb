require 'spec_helper'

describe PetState do
  it "has many swf_assets through parent_swf_asset_relationships" do
    pet_state = Factory.create :pet_state
    3.times do |n|
      swf_asset = Factory.create :swf_asset, :id => n, :url => "http://images.neopets.com/#{n}.swf", :type => 'biology'
      ParentSwfAssetRelationship.create :swf_asset => swf_asset, :pet_state => pet_state, :swf_asset_type => 'biology'
    end
    dud_swf_asset = Factory.create :swf_asset, :id => 3, :type => 'object'
    ParentSwfAssetRelationship.create :swf_asset => dud_swf_asset, :parent_id => 2, :swf_asset_type => 'biology'
    other_type_swf_asset = Factory.create :swf_asset, :id => 4, :type => 'biology'
    ParentSwfAssetRelationship.create :swf_asset => other_type_swf_asset, :parent_id => 1, :swf_asset_type => 'object'
    pet_state.swf_assets.map(&:id).should == [0, 1, 2]
    pet_state.swf_assets.map(&:url).should == ['http://images.neopets.com/0.swf',
      'http://images.neopets.com/1.swf', 'http://images.neopets.com/2.swf']
  end
end
