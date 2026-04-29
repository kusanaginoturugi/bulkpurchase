# frozen_string_literal: true

class AddCodeToOrganizations < ActiveRecord::Migration[8.0]
  ORGANIZATION_CODES = {
    "埼玉" => "31101",
    "千葉" => "31201",
    "大江戸" => "31303",
    "お台場" => "31305",
    "山梨" => "31901",
    "富士山" => "32204",
    "駿天" => "32205",
    "聖明王院" => "99300"
  }.freeze

  def up
    add_column :organizations, :code, :string
    add_index :organizations, :code, unique: true

    ORGANIZATION_CODES.each do |name, code|
      execute <<~SQL.squish
        UPDATE organizations
        SET code = #{quote(code)}
        WHERE name = #{quote(name)}
      SQL
    end
  end

  def down
    remove_index :organizations, :code
    remove_column :organizations, :code
  end
end
