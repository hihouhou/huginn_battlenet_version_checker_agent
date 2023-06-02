require 'rails_helper'
require 'huginn_agent/spec_helper'

describe Agents::BattlenetVersionCheckerAgent do
  before(:each) do
    @valid_options = Agents::BattlenetVersionCheckerAgent.new.default_options
    @checker = Agents::BattlenetVersionCheckerAgent.new(:name => "BattlenetVersionCheckerAgent", :options => @valid_options)
    @checker.user = users(:bob)
    @checker.save!
  end

  pending "add specs here"
end
