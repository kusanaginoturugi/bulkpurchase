# frozen_string_literal: true

class TendoSubmissionJob < ApplicationJob
  queue_as :default

  NOTIFICATION_EMAIL = ENV.fetch("TENDO_NOTIFICATION_EMAIL", "jimmyouou@gmail.com")

  def perform
    OrderCycle.ready_for_tendo_submission.find_each do |order_cycle|
      upload_pdf(order_cycle)
    end

    OrderCycle.ready_for_tendo_notification.find_each do |order_cycle|
      notify_by_email(order_cycle)
    end
  end

  private

  def upload_pdf(order_cycle)
    order_cycle.with_lock do
      return unless order_cycle.ready_for_tendo_submission?

      TendoPdfUploader.new(order_cycle).call
      order_cycle.update!(tendo_sent_at: Time.current, tendo_send_error: nil)
    end
  rescue StandardError => error
    record_error(order_cycle, "PDF送信に失敗しました: #{error.message}")
  end

  def notify_by_email(order_cycle)
    order_cycle.with_lock do
      return if order_cycle.tendo_sent_at.blank? || order_cycle.tendo_email_sent_at.present?

      OrderMailer.tendo_submission(order_cycle, NOTIFICATION_EMAIL).deliver_now
      order_cycle.update!(tendo_email_sent_at: Time.current, tendo_send_error: nil)
    end
  rescue StandardError => error
    record_error(order_cycle, "メール送信に失敗しました: #{error.message}")
  end

  def record_error(order_cycle, message)
    order_cycle.update_columns(tendo_send_error: message.truncate(500), updated_at: Time.current)
    Rails.logger.error("天道へのPDF自動送信に失敗しました: #{message}")
  end
end
