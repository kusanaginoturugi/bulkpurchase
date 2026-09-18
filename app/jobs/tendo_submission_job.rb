# frozen_string_literal: true

class TendoSubmissionJob < ApplicationJob
  queue_as :default

  def perform
    OrderCycle.ready_for_tendo_submission.find_each do |order_cycle|
      submit(order_cycle)
    end
  end

  private

  def submit(order_cycle)
    order_cycle.with_lock do
      return unless order_cycle.ready_for_tendo_submission?

      TendoPdfUploader.new(order_cycle).call
      order_cycle.update!(tendo_sent_at: Time.current, tendo_send_error: nil)
    end
  rescue StandardError => error
    order_cycle.update_columns(tendo_send_error: error.message.truncate(500), updated_at: Time.current)
    Rails.logger.error("天道へのPDF送信に失敗しました: #{error.message}")
  end
end
