# There was no Minitest equivalent; this covers the (previously untested)
# ProductsController, which requires a bearer token for every action.
require "rails_helper"

RSpec.describe "Products", type: :request do
  let(:user) { create(:user, password: "password123", password_confirmation: "password123") }
  let(:auth_token) do
    post "/auth/login", params: { email_address: user.email_address, password: "password123" }
    JSON.parse(response.body)["auth_token"]
  end
  let(:auth_headers) { { "Authorization" => "Bearer #{auth_token}" } }
  let!(:product) { create(:product) }

  describe "GET /products" do
    context "when authenticated" do
      it "returns the list of products" do
        get "/products", headers: auth_headers

        expect(response).to have_http_status(:ok)
        ids = JSON.parse(response.body).map { |p| p["id"] }
        expect(ids).to include(product.id)
      end
    end

    context "when not authenticated" do
      it "responds with 401" do
        get "/products"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /products/:id" do
    context "when authenticated" do
      it "returns the product" do
        get "/products/#{product.id}", headers: auth_headers

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["id"]).to eq product.id
        expect(body["name"]).to eq product.name
      end
    end

    context "when not authenticated" do
      it "responds with 401" do
        get "/products/#{product.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /products" do
    context "when authenticated" do
      it "creates the product" do
        expect {
          post "/products",
               params: { product: { name: "New", category: "Cat", quantity: 5, price: 100 } },
               headers: auth_headers
        }.to change(Product, :count).by(1)

        expect(response).to have_http_status(:created)
      end
    end

    context "when not authenticated" do
      it "responds with 401" do
        post "/products", params: { product: { name: "New" } }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when the product cannot be saved" do
      it "responds with 422 and the error messages" do
        invalid = instance_double(Product, save: false, errors: { name: ["can't be blank"] })
        allow(Product).to receive(:new).and_return(invalid)

        post "/products", params: { product: { name: "New" } }, headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)).to include("name")
      end
    end
  end

  describe "PATCH /products/:id" do
    context "when authenticated" do
      it "updates the product" do
        patch "/products/#{product.id}", params: { product: { quantity: 42 } }, headers: auth_headers

        expect(response).to have_http_status(:ok)
        expect(product.reload.quantity).to eq 42
      end
    end

    context "when the product cannot be updated" do
      it "responds with 422 and the error messages" do
        invalid = instance_double(Product, update: false, errors: { name: ["can't be blank"] })
        allow(Product).to receive(:find).and_return(invalid)

        patch "/products/#{product.id}", params: { product: { name: "Renamed" } }, headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)).to include("name")
      end
    end
  end

  describe "DELETE /products/:id" do
    context "when authenticated" do
      it "deletes the product" do
        expect {
          delete "/products/#{product.id}", headers: auth_headers
        }.to change(Product, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end
    end
  end
end