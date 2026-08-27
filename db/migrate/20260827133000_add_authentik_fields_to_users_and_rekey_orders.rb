# frozen_string_literal: true

class AddAuthentikFieldsToUsersAndRekeyOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :authentik_subject, :string
    add_column :users, :authentik_groups, :text
    add_index :users, :authentik_subject, unique: true

    remove_index :orders, %i[user_id order_cycle_id]
    add_index :orders, %i[fellowship_id order_cycle_id]
  end
end
