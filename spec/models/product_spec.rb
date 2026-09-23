# Ported from test/models/product_test.rb (Minitest).
require "rails_helper"

RSpec.describe Product, type: :model do
  let!(:product) { create(:product) }

  it "persists its attributes" do
    expect(product.reload.name).to be_present
    expect(product.category).to be_present
    expect(product.quantity).to be_a(Integer)
    expect(product.price).to be_a(Integer)
  end
end