require 'spec_helper'

describe Zone do
  specify "should find by id, report label" do
    Zone.find(1).label.should == 'Music'
    Zone.find(3).label.should == 'Background'
  end
end
