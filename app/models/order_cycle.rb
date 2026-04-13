class OrderCycle < ApplicationRecord
  has_many :orders, dependent: :restrict_with_exception

  enum :status, {
    open: "open",
    closed: "closed",
    sent: "sent"
  }, validate: true

  validates :year, :month, :cycle_number, :deadline_at, :order_date, :arrival_date, presence: true
  validates :month, inclusion: { in: 1..12 }
  validates :year, uniqueness: { scope: :month }
  validate :deadline_must_not_be_after_order_date

  scope :recent_first, -> { order(year: :desc, month: :desc) }
  scope :editable_by_users, -> { where.not(status: "sent").recent_first }

  def label
    format("%<year>d年%<month>02d月", year:, month:)
  end

  def editable_by_users?
    !sent?
  end

  def self.current_for_user
    editable_by_users.first
  end

  private
    def deadline_must_not_be_after_order_date
      return if deadline_at.blank? || order_date.blank?
      return if deadline_at.to_date <= order_date

      errors.add(:deadline_at, "must be on or before the order date")
    end
end
