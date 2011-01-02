require "spec_helper"

describe RFTP::Client do
  context "initialization and credentials" do
    let(:client) { RFTP::Client.new("example.org", "user", "pass") }

    it "sets the credentials when you initialize" do
      {:host => "example.org", :user => "user", :passwd => "pass"}.each do |key, value|
        client.credentials[key].should == value
      end
    end

    it "allows you to update the credentials after you initialize" do
      client.credentials.host = "example.com"
      client.credentials.host.should == "example.com"
    end
  end


end

