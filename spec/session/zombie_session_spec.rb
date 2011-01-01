require File.expand_path('../spec_helper', File.dirname(__FILE__))

describe Capybara::Driver::Zombie do
  session = nil

  before do
    @session = (session ||= Capybara::Session.new(:zombie, TestApp))
  end

  describe '#driver' do
    it "should be an zombie driver" do
      @session.driver.should be_an_instance_of(Capybara::Driver::Zombie)
    end
  end

  describe '#mode' do
    it "should remember the mode" do
      @session.mode.should == :zombie
    end
  end

  # it_should_behave_like "session"
  # it_should_behave_like "session with javascript support"
  # it_should_behave_like "session with headers support"
  # it_should_behave_like "session with status code support"
end
