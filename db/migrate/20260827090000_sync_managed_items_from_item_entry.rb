# frozen_string_literal: true

require "csv"

class SyncManagedItemsFromItemEntry < ActiveRecord::Migration[8.0]
  def up
    codes = []

    CSV.foreach(Rails.root.join("items.csv"), headers: true) do |row|
      code = row.fetch("code")
      next unless code.between?("100400", "210008")

      codes << code
      item = Item.find_or_initialize_by(code:)
      item.update!(
        name: row.fetch("name"),
        value: row.fetch("value").to_i,
        refund: row.fetch("refund").to_i,
        unit: infer_unit(row.fetch("name")),
        center_category: :other,
        special_handling_type: row.fetch("name").include?("白陽八卦符") ? :hakuyo_hakke : :none,
        active: true
      )
    end

    Item.where(code: "100400".."210008").where.not(code: codes).update_all(active: false)
  end

  def down
    # 外部道具一覧に合わせる同期のため、戻し処理は行いません。
  end

  private

  def infer_unit(name)
    return "組" if name.include?("1組")
    return "組" if %w[白陽八卦符 みろく鵺符 灶君護摩符 大國陰陽符].any? { |keyword| name.include?(keyword) }
    return "本" if %w[護摩木 御柱 棒].any? { |keyword| name.include?(keyword) }
    return "枚" if %w[札 符 人型 銭型 金紙 銀紙 暦].any? { |keyword| name.include?(keyword) }

    "個"
  end
end
