# frozen_string_literal: true

class OrderItem < ApplicationRecord
  FIXED_UNITS = {
    "修霊超抜之御柱" => "本"
  }.freeze

  belongs_to :order
  belongs_to :item, optional: true
  belongs_to :item_variant, optional: true

  validates :item_name, :unit, presence: true
  validates :quantity, numericality: { greater_than: 0, only_integer: true }
  validate :variant_required_for_special_items

  before_validation :sync_from_item
  before_validation :sync_fixed_unit

  def output_name
    [ item_name, variant_name.presence && "(#{variant_name})" ].compact.join
  end

  private

  def sync_from_item
    return unless item

    self.item_code = item.code
    self.item_name = item.name if item_name.blank?
    self.unit = item.unit

    return unless item_variant

    self.variant_name = item_variant.name
  end

  def sync_fixed_unit
    self.unit = FIXED_UNITS[item_name.to_s.strip] if FIXED_UNITS.key?(item_name.to_s.strip)
  end

  def variant_required_for_special_items
    return unless item&.variant_required?
    return if variant_name.present?

    errors.add(:variant_name, "を入力してください")
  end
end
