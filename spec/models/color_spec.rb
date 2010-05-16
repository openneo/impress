require 'spec_helper'

describe Color do
  specify "should find by id, report name" do
    Color.find(1).name.should == 'alien'
    Color.find(2).name.should == 'apple'
  end
  
  specify "should find by name, report id" do
    Color.find_by_name('alien').id.should == 1
    Color.find_by_name('apple').id.should == 2
  end
  
  specify "name should be case-insensitive" do
    Color.find_by_name('Alien').id.should == 1
    Color.find_by_name('alien').id.should == 1
  end
end
