# frozen_string_literal: true

class CreateItems < ActiveRecord::Migration[8.0]
  def change
    create_table :items do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.integer :value, null: false, default: 0
      t.integer :refund, null: false, default: 0
      t.string :unit
      t.string :center_category, null: false, default: 'other'
      t.string :special_handling_type, null: false, default: 'none'
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :items, :code, unique: true
    add_index :items, :name
  end
end
