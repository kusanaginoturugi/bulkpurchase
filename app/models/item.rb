# frozen_string_literal: true

class Item < ApplicationRecord
  has_many :item_variants, -> { order(:display_order, :id) }, dependent: :destroy
  has_many :order_items, dependent: :restrict_with_exception

  enum :center_category, {
    center_1: "center_1",
    center_2: "center_2",
    other: "other"
  }, validate: true

  enum :special_handling_type, {
    none: "none",
    hakuyo_hakke: "hakuyo_hakke"
  }, prefix: :special_handling, validate: true

  validates :code, :name, presence: true
  validates :code, uniqueness: true

  scope :active, -> { where(active: true) }
  scope :searchable, -> { active.where(center_category: %w[center_1 center_2]) }

  def variant_required?
    special_handling_hakuyo_hakke?
  end
end
