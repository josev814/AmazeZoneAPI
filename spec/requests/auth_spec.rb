# Ported from test/controllers/auth_controller_test.rb (Minitest).
require "rails_helper"

RSpec.describe "Authentication", type: :request do
  let(:user) { create(:user, password: "password123", password_confirmation: "password123") }
  let(:login_params) { { email_address: user.email_address, password: "password123" } }

  describe "POST /auth/login" do
    context "when the credentials are valid" do
      it "responds with 200 and a JWT auth token" do
        post "/auth/login", params: login_params

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to include("auth_token")
      end
    end

    context "when the password is wrong" do
      it "responds with 401 and an error" do
        post "/auth/login", params: { email_address: user.email_address, password: "nope" }

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)).to include("error")
      end
    end

    context "when the user does not exist" do
      it "responds with 401" do
        post "/auth/login", params: { email_address: "ghost@example.com", password: "password123" }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /auth/current" do
    let(:token) do
      post "/auth/login", params: login_params
      JSON.parse(response.body)["auth_token"]
    end

    context "with a valid bearer token" do
      it "responds with 200 and the user's email and name" do
        get "/auth/current", headers: { "Authorization" => "Bearer #{token}" }

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["email_address"]).to eq user.email_address
        expect(body["name"]).to eq user.name
      end
    end

    context "without a token" do
      it "responds with 401" do
        get "/auth/current"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end