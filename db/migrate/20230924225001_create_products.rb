class CreateProducts < ActiveRecord::Migration[8.0]
  def change
    create_table :products do |t|
      t.string :name
      t.string :category
      t.integer :quantity
      t.integer :price

      t.timestamps
    end
  end
end
