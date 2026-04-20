# frozen_string_literal: true

class Order < ApplicationRecord
  belongs_to :user
  belongs_to :organization
  belongs_to :order_cycle
  has_many :order_items, -> { order(:sort_order, :id) }, dependent: :destroy, inverse_of: :order

  accepts_nested_attributes_for :order_items,
                                allow_destroy: true,
                                reject_if: lambda { |attributes|
                                  %w[item_code item_name variant_name quantity unit notes].all? { |key|
                                    attributes[key].blank?
                                  }
                                }

  enum :status, {
    draft: "draft",
    submitted: "submitted"
  }, validate: true

  validates :orderer_name, :pickup_name, presence: true
  validates :user_id, uniqueness: { scope: :order_cycle_id }
  validate :submitted_orders_must_have_items

  before_validation :sync_organization

  def editable_by_user?
    order_cycle.editable_by_users?
  end

  def status_label
    I18n.t("enums.order.status.#{status}", default: status)
  end

  def mark_submitted!
    self.status = "submitted"
    self.submitted_at = Time.current
  end

  private

  def sync_organization
    self.organization ||= user&.organization
  end

  def submitted_orders_must_have_items
    return unless submitted?
    return if order_items.reject(&:marked_for_destruction?).any?

    errors.add(:base, "提出時は明細を1行以上入力してください")
  end
end
