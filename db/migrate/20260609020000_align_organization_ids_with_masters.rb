# frozen_string_literal: true

class AlignOrganizationIdsWithMasters < ActiveRecord::Migration[8.1]
  ID_REMAP = {
    "31101" => 15,
    "31201" => 16,
    "31303" => 18,
    "31304" => 19,
    "31305" => 20,
    "31407" => 24,
    "31901" => 25,
    "32204" => 27,
    "32205" => 28,
    "99300" => 88
  }.freeze

  OFFSET = 100_000

  def up
    execute "PRAGMA defer_foreign_keys = ON"

    execute "UPDATE users SET organization_id = organization_id + #{OFFSET}"
    execute "UPDATE orders SET organization_id = organization_id + #{OFFSET}"
    execute "UPDATE organizations SET id = id + #{OFFSET}"

    current = select_all("SELECT id, code FROM organizations").to_a
    current.each do |row|
      code = row["code"]
      new_id = ID_REMAP[code]
      next unless new_id

      old_id = row["id"]
      execute "UPDATE users SET organization_id = #{new_id} WHERE organization_id = #{old_id}"
      execute "UPDATE orders SET organization_id = #{new_id} WHERE organization_id = #{old_id}"
      execute "UPDATE organizations SET id = #{new_id} WHERE id = #{old_id}"
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
