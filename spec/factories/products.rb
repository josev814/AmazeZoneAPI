FactoryBot.define do
  factory :product do
    sequence(:name) { |n| "Product #{n}" }
    category { "General" }
    quantity { 10 }
    price { 500 }
  end
end
