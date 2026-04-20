# frozen_string_literal: true

class CreateOrderCycles < ActiveRecord::Migration[8.0]
  def change
    create_table :order_cycles do |t|
      t.integer :year, null: false
      t.integer :month, null: false
      t.integer :cycle_number, null: false
      t.datetime :deadline_at, null: false
      t.date :order_date, null: false
      t.date :arrival_date, null: false
      t.string :status, null: false, default: 'open'

      t.timestamps
    end

    add_index :order_cycles, %i[year month], unique: true
  end
end
