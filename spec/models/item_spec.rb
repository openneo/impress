require 'spec_helper'

describe Item do
  context "an item" do
    before(:each) do
      @item = Factory.create :item
    end
    
    specify "should accept string or array for species_support_ids" do
      @item.species_support_ids = '1,2,3'
      @item.species_support_ids.should == [1, 2, 3]
      @item.species_support_ids = [4, 5, 6]
      @item.species_support_ids.should == [4, 5, 6]
    end
    
    specify "should provide list of supported species objects" do
      @item.species_support_ids = [1, 2, 3]
      @item.supported_species.map { |s| s.name }.should == ['acara', 'aisha', 'blumaroo']
    end
    
    specify "should provide all species if no support ids" do
      @item.species_support_ids = ''
      @item.supported_species.count.should be > 0
    end
    
    specify "should have many swf_assets through parent_swf_asset_relationships" do
      3.times do |n|
        swf_asset = Factory.create :swf_asset, :id => n, :url => "http://images.neopets.com/#{n}.swf", :type => 'object'
        ParentSwfAssetRelationship.create :swf_asset => swf_asset, :item => @item, :swf_asset_type => 'object'
      end
      dud_swf_asset = Factory.create :swf_asset, :id => 3, :type => 'object'
      ParentSwfAssetRelationship.create :swf_asset => dud_swf_asset, :parent_id => 2, :swf_asset_type => 'object'
      other_type_swf_asset = Factory.create :swf_asset, :id => 4, :type => 'biology'
      ParentSwfAssetRelationship.create :swf_asset => other_type_swf_asset, :parent_id => 1, :swf_asset_type => 'biology'
      @item.swf_assets.map(&:id).should == [0, 1, 2]
      @item.swf_assets.map(&:url).should == ['http://images.neopets.com/0.swf',
        'http://images.neopets.com/1.swf', 'http://images.neopets.com/2.swf']
    end
  end
  
  context "class" do
    specify "should search name for word" do
      query_should 'blue',
        :return => [
          'A Hat That is Blue',
          'Blue Hat',
          'Blueish Hat',
          'Very Blue Hat'
        ],
        :not_return => [
          'Green Hat',
          'Red Hat'
        ]
    end
    
    specify "should search name for phrase" do
      query_should '"one two"',
        :return => [
          'Zero one two three',
          'Zero one two',
          'One two three'
        ],
        :not_return => [
          'Zero one three',
          'Zero two three',
          'Zero one and two',
          'Three two one'
        ]
    end
    
    specify "should search name for multiple words" do
      query_should 'one two',
        :return => [
          'Zero one two three',
          'Zero one two',
          'One two three',
          'Zero one and two',
          'Three two one'
        ],
        :not_return => [
          'Zero one three',
          'Zero two three'
        ]
    end
    
    specify "should search name for words and phrases" do
      query_should 'zero "one two" three',
        :return => [
          'zero one two three',
          'zero four one two three',
          'one two zero three',
          'three zero one two'
        ],
        :not_return => [
          'one two three',
          'zero one two',
          'three one zero two',
          'two one three zero'
        ]
    end
    
    specify "should search description for words and phrases" do
      query_should 'description:zero description:"one two"',
        :return => [
          ['Green Hat', 'zero one two three'],
          ['Blue Hat', 'five one two four zero']
        ],
        :not_return => [
          'Zero one two',
          ['Zero one', 'two'],
          ['Zero', 'One two'],
          ['Three', 'One zero two']
        ]
    end
    
    specify "should search by species" do
      [[2],[1,2,3],[2,3],[3],[1,3]].each do |ids|
        Factory.create :item, :species_support_ids => ids
      end
      Item.search('species:acara').count.should == 2
      Item.search('species:aisha').count.should == 3
      Item.search('species:blumaroo').count.should == 4
    end
    
    specify "should search by species and words" do
      Factory.create :item, :name => 'Blue Hat', :species_support_ids => [1]
      Factory.create :item, :name => 'Very Blue Hat', :species_support_ids => [1,2]
      Factory.create :item, :name => 'Red Hat', :species_support_ids => [2]
      Item.search('blue species:acara').count.should == 2
      Item.search('blue species:aisha').count.should == 1
      Item.search('red species:acara').count.should == 0
      Item.search('red species:aisha').count.should == 1
    end
    
    specify "should return items with no species requirements if a species condition is added" do
      Factory.create :item, :species_support_ids => [1]
      Factory.create :item, :species_support_ids => [1,2]
      Factory.create :item, :species_support_ids => []
      Item.search('species:acara').count.should == 3
      Item.search('species:aisha').count.should == 2
      Item.search('species:acara species:aisha').count.should == 2
      Item.search('-species:acara').count.should == 0
      Item.search('-species:aisha').count.should == 1
    end
    
    specify "should search by only:species" do
      Factory.create :item, :species_support_ids => [1], :name => 'a'
      Factory.create :item, :species_support_ids => [1,2], :name => 'b'
      Factory.create :item, :species_support_ids => [], :name => 'c'
      Item.search('only:acara').map(&:name).should == ['a']
      Item.search('only:aisha').count.should == 0
      Item.search('-only:acara').map(&:name).should == ['b', 'c']
      Item.search('-only:aisha').map(&:name).should == ['a', 'b', 'c']
    end
    
    specify "should be able to negate word in search" do
      query_should 'hat -blue',
        :return => [
          'Green Hat',
          'Red Hat',
          'Blu E Hat',
        ],
        :not_return => [
          'Blue Hat',
          'Green Shirt',
          'Blue Shirt',
        ]
    end
    
    specify "should be able to negate species in search" do
      Factory.create :item, :name => 'Blue Hat', :species_support_ids => [1]
      Factory.create :item, :name => 'Very Blue Hat', :species_support_ids => [1,2]
      Factory.create :item, :name => 'Red Hat', :species_support_ids => [1,2]
      Factory.create :item, :name => 'Green Hat', :species_support_ids => [3]
      Factory.create :item, :name => 'Red Shirt', :species_support_ids => [3]
      Item.search('hat -species:acara').count.should == 1
      Item.search('hat -species:aisha').count.should == 2
      Item.search('hat -species:acara -species:aisha').count.should == 1
    end
    
    specify "should be able to negate phrase in search" do
      query_should 'zero -"one two"',
        :return => [
          'Zero two one',
          'One three two zero'
        ],
        :not_return => [
          'Zero one two',
          'One two three zero'
        ]
    end
    
    specify "should raise exception for a query with no conditions" do
      [
        lambda { Item.search('').all },
        lambda { Item.search(nil).all },
        lambda { Item.search(' ').all }
      ].each { |l| l.should raise_error(ArgumentError) }
    end
    
    specify "should raise exception for a query that's too short" do
      lambda { Item.search('e').all }.should raise_error(ArgumentError)
    end
    
    specify "should not be able to search other attributes thru filters" do
      lambda { Item.search('id:1').all }.should raise_error(ArgumentError)
    end
    
    specify "should raise exception if species not found" do
      lambda { Item.search('species:hurfdurfdurf').all }.should raise_error(ArgumentError)
    end
  end
end
