require 'spec_helper'

describe Item do
  context "an item" do
    specify "should accept string or array for species_support_ids" do
      items = [
        Factory.build(:item, :species_support_ids => '1,2,3'),
        Factory.build(:item, :species_support_ids => [1,2,3])
      ]
      items.each { |i| i.species_support_ids.should == [1,2,3] }
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
  end
end
