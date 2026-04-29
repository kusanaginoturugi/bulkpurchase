# frozen_string_literal: true

require "csv"

class ImportManagedItems < ActiveRecord::Migration[8.0]
  def up
    CSV.foreach(Rails.root.join("items.csv"), headers: true) do |row|
      code = row.fetch("code")
      next unless code.start_with?("1", "2")

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

    ensure_hakuyo_hakke_variants
  end

  def down
    # 道具は注文明細から参照されるため、自動削除しません。
  end

  private

  def infer_unit(name)
    return "組" if %w[白陽八卦符 みろく鵺符].any? { |keyword| name.include?(keyword) }
    return "本" if %w[護摩木 御柱 棒].any? { |keyword| name.include?(keyword) }
    return "枚" if %w[札 符 人型 銭型 金紙 銀紙 暦].any? { |keyword| name.include?(keyword) }

    "個"
  end

  def ensure_hakuyo_hakke_variants
    hakke = Item.find_by(name: "白陽八卦符")
    return unless hakke

    %w[無地 有気復命].each_with_index do |name, index|
      hakke.item_variants.find_or_create_by!(name:) do |variant|
        variant.display_order = index
        variant.active = true
      end
    end
  end
end
