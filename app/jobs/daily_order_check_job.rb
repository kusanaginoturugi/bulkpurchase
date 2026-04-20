# frozen_string_literal: true

class DailyOrderCheckJob < ApplicationJob
  queue_as :default

  def perform
    reminder_target_cycles.each do |order_cycle|
      order_cycle.orders.submitted.includes(:user).find_each do |order|
        OrderMailer.reminder(order).deliver_later
      end
    end

    summary_target_cycles.each do |order_cycle|
      recipients = User.admin.active.pluck(:email_address)
      next if recipients.empty?

      OrderMailer.summary(order_cycle, recipients).deliver_later
      order_cycle.update!(status: :sent)
    end
  end

  private

  def reminder_target_cycles
    OrderCycle.where(order_date: Date.current + 1.day).where.not(status: :sent)
  end

  def summary_target_cycles
    OrderCycle.where(order_date: Date.current).where.not(status: :sent)
  end
end
