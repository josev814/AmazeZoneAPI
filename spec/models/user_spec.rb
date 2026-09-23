# Ported from test/models/user_test.rb (Minitest).
require "rails_helper"

RSpec.describe User, type: :model do
  describe "has_secure_password" do
    it "stores a password digest instead of the plain-text password" do
      user = create(:user, password: "s3cret!", password_confirmation: "s3cret!")
      expect(user.reload.password_digest).to be_present
    end

    it "authenticates with the correct password" do
      user = create(:user, password: "s3cret!", password_confirmation: "s3cret!")
      expect(user.authenticate("s3cret!")).to eq user
    end

    it "does not authenticate with an incorrect password" do
      user = create(:user)
      expect(user.authenticate("wrong-password")).to be false
    end
  end

  it { is_expected.to respond_to(:email_address) }
  it { is_expected.to respond_to(:name) }
end