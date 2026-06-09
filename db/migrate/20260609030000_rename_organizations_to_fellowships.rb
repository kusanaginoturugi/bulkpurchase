# frozen_string_literal: true

class RenameOrganizationsToFellowships < ActiveRecord::Migration[8.1]
  def change
    rename_table :organizations, :fellowships
    rename_column :orders, :organization_id, :fellowship_id
    rename_column :users, :organization_id, :fellowship_id
  end
end
