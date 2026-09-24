# frozen_string_literal: true

require "test_helper"

class TendoSubmissionJobTest < ActiveJob::TestCase
  setup do
    ActionMailer::Base.deliveries.clear
  end

  test "PDF自動送信後に通知先へPDFをメール送信する" do
    order_cycle = OrderCycle.create!(
      year: 2032,
      month: 1,
      cycle_number: 1,
      deadline_at: Time.zone.local(2032, 1, 1, 12),
      arrival_date: Date.new(2032, 1, 10),
      tendo_sent_at: Time.current
    )

    TendoSubmissionJob.perform_now

    assert_equal [ "jimmyouou@gmail.com" ], ActionMailer::Base.deliveries.last.to
    assert_equal 1, ActionMailer::Base.deliveries.last.attachments.size
    assert_predicate order_cycle.reload.tendo_email_sent_at, :present?
  end
end
