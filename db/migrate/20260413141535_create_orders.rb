# frozen_string_literal: true

class CreateOrders < ActiveRecord::Migration[8.0]
  def change
    create_table :orders do |t|
      t.references :user, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.references :order_cycle, null: false, foreign_key: true
      t.string :orderer_name, null: false
      t.string :pickup_name, null: false
      t.string :status, null: false, default: 'draft'
      t.datetime :submitted_at

      t.timestamps
    end

    add_index :orders, %i[user_id order_cycle_id], unique: true
  end
end
