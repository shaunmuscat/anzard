require 'rails_helper'


describe Hospital do
  describe "Associations" do
    it { should have_many(:users) }
    it { should have_many(:responses) }
  end

  describe "Validations" do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:state) }
    it { should validate_presence_of(:unit) }
    it { should validate_presence_of(:site) }
  end

  describe "Grouping Hospitals By State" do
    it "should put the states in alphabetic order then the hospitals under then in alphabetic order" do
      rpa = create(:hospital, state: "NSW", name: "RPA").id
      royal_childrens = create(:hospital, state: "Vic", name: "The Royal Childrens Hospital").id
      campbelltown = create(:hospital, state: "NSW", name: "Campbelltown").id
      liverpool = create(:hospital, state: "NSW", name: "Liverpool").id
      mercy = create(:hospital, state: "Vic", name: "Mercy Hospital").id
      royal_ad = create(:hospital, state: "SA", name: "Royal Adelaide").id

      output = Hospital.hospitals_by_state
      output.size.should eq(3)
      output[0][0].should eq("NSW")
      output[1][0].should eq("SA")
      output[2][0].should eq("Vic")

      output[0][1].should eq([["Campbelltown", campbelltown], ["Liverpool", liverpool], ["RPA", rpa]])
      output[1][1].should eq([["Royal Adelaide", royal_ad]])
      output[2][1].should eq([["Mercy Hospital", mercy], ["The Royal Childrens Hospital", royal_childrens]])
    end
  end


end
