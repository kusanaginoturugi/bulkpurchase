# frozen_string_literal: true

class AddEnabledToOrganizations < ActiveRecord::Migration[8.1]
  def up
    add_column :organizations, :enabled, :boolean, null: false, default: false
    execute "UPDATE organizations SET enabled = 1 WHERE code IS NOT NULL"
  end

  def down
    remove_column :organizations, :enabled
  end
end
