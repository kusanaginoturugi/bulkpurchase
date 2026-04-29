# frozen_string_literal: true

class AddAdditionalOrganizations < ActiveRecord::Migration[8.0]
  ORGANIZATIONS = {
    "羽田" => "31304",
    "かながわ" => "31407"
  }.freeze

  def up
    ORGANIZATIONS.each do |name, code|
      execute <<~SQL.squish
        INSERT INTO organizations (code, name, active, created_at, updated_at)
        SELECT #{quote(code)}, #{quote(name)}, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
        WHERE NOT EXISTS (
          SELECT 1 FROM organizations
          WHERE code = #{quote(code)} OR name = #{quote(name)}
        )
      SQL
    end
  end

  def down
    ORGANIZATIONS.each do |name, code|
      execute <<~SQL.squish
        DELETE FROM organizations
        WHERE code = #{quote(code)} AND name = #{quote(name)}
      SQL
    end
  end
end
