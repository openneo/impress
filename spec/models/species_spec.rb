require 'spec_helper'

describe Species do
  specify "should find by id, report name" do
    Species.find(1).name.should == 'acara'
    Species.find(2).name.should == 'aisha'
  end
  
  specify "should find by name, report id" do
    Species.find_by_name('acara').id.should == 1
    Species.find_by_name('aisha').id.should == 2
  end
  
  specify "name should be case-insensitive" do
    Species.find_by_name('Acara').id.should == 1
    Species.find_by_name('acara').id.should == 1
  end
end
