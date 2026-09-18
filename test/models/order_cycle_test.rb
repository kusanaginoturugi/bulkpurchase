# frozen_string_literal: true

require "test_helper"

class OrderCycleTest < ActiveSupport::TestCase
  test "PDF自動送信には日時と送信先の両方が必要" do
    order_cycle = OrderCycle.new(
      year: 2030,
      month: 1,
      cycle_number: 1,
      deadline_at: Time.zone.local(2030, 1, 1, 12),
      arrival_date: Date.new(2030, 1, 10),
      tendo_send_at: Time.zone.local(2030, 1, 2, 9)
    )

    assert_not_predicate order_cycle, :valid?
    assert_includes order_cycle.errors.full_messages, "PDF自動送信日時と送信先を入力してください"
  end

  test "送信日時を過ぎた未送信の注文サイクルを取得する" do
    order_cycle = OrderCycle.create!(
      year: 2030,
      month: 2,
      cycle_number: 2,
      deadline_at: Time.zone.local(2030, 2, 1, 12),
      arrival_date: Date.new(2030, 2, 10),
      tendo_send_at: 1.minute.ago,
      tendo_destination: "mirokuji"
    )

    assert_includes OrderCycle.ready_for_tendo_submission, order_cycle
  end
end
