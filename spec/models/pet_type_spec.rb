require 'spec_helper'

describe PetType do
  context "object" do
    specify "should return id, body_id in JSON" do
      pet_type = PetType.create :color_id => 2, :species_id => 3, :body_id => 4
      pet_type.as_json.should == {:id => 1, :body_id => 4}
    end
    
    specify "should allow setting species object" do
      pet_type = PetType.new
      pet_type.species = Species.find(1)
      pet_type.species_id.should == 1
      pet_type.species.id.should == 1
      pet_type.species.name.should == 'acara'
    end
    
    specify "should allow setting color object" do
      pet_type = PetType.new
      pet_type.color = Color.find(1)
      pet_type.color_id.should == 1
      pet_type.color.id.should == 1
      pet_type.color.name.should == 'alien'
    end
    
    specify "should return image hash if a basic color" do
      blue = Color.find_by_name('blue')
      acara = Species.find_by_name('acara')
      pet_type = PetType.new :color => blue, :species => acara
      pet_type.image_hash.should == 'mnbztxxn'
    end
    
    specify "should return nil for image hash if not a basic color" do
      asparagus = Color.find_by_name('asparagus')
      acara = Species.find_by_name('acara')
      pet_type = PetType.new :color => asparagus, :species => acara
      pet_type.image_hash.should be nil
    end
    
    specify "should have many swf_assets through parent_swf_asset_relationships" do
      pet_type = Factory.create :pet_type
      3.times do |n|
        swf_asset = Factory.create :swf_asset, :id => n, :url => "http://images.neopets.com/#{n}.swf", :type => 'biology'
        ParentSwfAssetRelationship.create :swf_asset => swf_asset, :item => pet_type, :swf_asset_type => 'biology'
      end
      dud_swf_asset = Factory.create :swf_asset, :id => 3, :type => 'object'
      ParentSwfAssetRelationship.create :swf_asset => dud_swf_asset, :parent_id => 2, :swf_asset_type => 'biology'
      other_type_swf_asset = Factory.create :swf_asset, :id => 4, :type => 'biology'
      ParentSwfAssetRelationship.create :swf_asset => other_type_swf_asset, :parent_id => 1, :swf_asset_type => 'object'
      pet_type.swf_assets.map(&:id).should == [0, 1, 2]
      pet_type.swf_assets.map(&:url).should == ['http://images.neopets.com/0.swf',
        'http://images.neopets.com/1.swf', 'http://images.neopets.com/2.swf']
    end
  end
end
