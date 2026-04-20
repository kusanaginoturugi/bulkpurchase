# frozen_string_literal: true

class AddBusinessFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :name, :string, null: false
    add_reference :users, :organization, null: false, foreign_key: true
    add_column :users, :role, :string, null: false, default: 'user'
    add_column :users, :active, :boolean, null: false, default: true
  end
end
