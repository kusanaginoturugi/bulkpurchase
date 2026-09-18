# frozen_string_literal: true

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
  validate :tendo_destination_is_valid
  validate :tendo_schedule_is_complete

  before_validation :derive_dates_and_cycle_number

  scope :recent_first, -> { order(year: :desc, month: :desc) }
  scope :editable_by_users, -> { where.not(status: "sent").recent_first }
  scope :upcoming_for_users, -> { where.not(status: "sent").where(deadline_at: Time.current..).order(:deadline_at) }
  scope :ready_for_tendo_submission, -> { where.not(tendo_send_at: nil).where(tendo_sent_at: nil).where(tendo_send_at: ..Time.current) }

  def label
    format("%<year>d年%<month>02d月", year:, month:)
  end

  def status_label
    I18n.t("enums.order_cycle.status.#{status}", default: status)
  end

  def editable_by_users?
    !sent?
  end

  def ready_for_tendo_submission?
    tendo_send_at.present? && tendo_sent_at.blank? && tendo_send_at <= Time.current
  end

  def tendo_destination_label
    {
      "mirokuji" => "弥勒寺",
      "kannondo" => "観音堂"
    }[tendo_destination]
  end

  def tendo_submission_status_label
    return "送信済み（#{I18n.l(tendo_sent_at, format: :long)}）" if tendo_sent_at.present?
    return "未設定" if tendo_send_at.blank?
    return "送信失敗" if tendo_send_error.present?

    "送信待ち（#{I18n.l(tendo_send_at, format: :long)}）"
  end

  def self.tendo_destination_options
    [ [ "弥勒寺へ送信", "mirokuji" ], [ "観音堂へ送信", "kannondo" ] ]
  end

  def self.current_for_user
    upcoming_for_users.first || editable_by_users.first
  end

  def self.status_options
    statuses.keys.map { |value| [ I18n.t("enums.order_cycle.status.#{value}", default: value), value ] }
  end

  private

  def derive_dates_and_cycle_number
    self.cycle_number = month if cycle_number.blank? && month.present?
    self.order_date = deadline_at.to_date.next_day if deadline_at.present?
  end

  def deadline_must_not_be_after_order_date
    return if deadline_at.blank? || order_date.blank?
    return if deadline_at.to_date <= order_date

    errors.add(:deadline_at, "must be on or before the order date")
  end

  def tendo_destination_is_valid
    return if tendo_destination.blank? || self.class.tendo_destination_options.map(&:last).include?(tendo_destination)

    errors.add(:tendo_destination, "を選択してください")
  end

  def tendo_schedule_is_complete
    return if tendo_send_at.blank? && tendo_destination.blank?
    return if tendo_send_at.present? && tendo_destination.present?

    errors.add(:base, "PDF自動送信日時と送信先を入力してください")
  end
end
