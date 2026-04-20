# frozen_string_literal: true

class CreateOrderItems < ActiveRecord::Migration[8.0]
  def change
    create_table :order_items do |t|
      t.references :order, null: false, foreign_key: true
      t.references :item, null: true, foreign_key: true
      t.references :item_variant, null: true, foreign_key: true
      t.string :item_code
      t.string :item_name, null: false
      t.string :variant_name
      t.integer :quantity, null: false
      t.string :unit, null: false
      t.text :notes
      t.integer :sort_order, null: false, default: 0

      t.timestamps
    end
  end
end
