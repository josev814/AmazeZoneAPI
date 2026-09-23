# Ported from test/controllers/users_controller_test.rb (Minitest).
require "rails_helper"

RSpec.describe "Users", type: :request do
  let(:valid_user_params) do
    {
      name: "New User",
      email_address: "newuser@example.com",
      password: "password123",
      password_confirmation: "password123"
    }
  end

  describe "POST /signup" do
    context "with valid attributes" do
      it "creates the user and responds with 201" do
        expect {
          post "/signup", params: { user: valid_user_params }
        }.to change(User, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(JSON.parse(response.body)["message"]).to eq "User created successfully"
      end
    end

    context "with a malformed email address" do
      it "does not create a user and responds with 422 and the error messages" do
        params = { user: valid_user_params.merge(email_address: "not-an-email") }

        expect {
          post "/signup", params: params
        }.not_to change(User, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)["errors"]).to be_present
      end
    end

    context "with a missing password" do
      it "does not create a user and responds with 422" do
        user_params = valid_user_params.except(:password, :password_confirmation)

        expect {
          post "/signup", params: { user: user_params }
        }.not_to change(User, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end