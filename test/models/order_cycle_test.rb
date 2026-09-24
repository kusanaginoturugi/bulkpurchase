# frozen_string_literal: true

require "test_helper"

class OrderCycleTest < ActiveSupport::TestCase
  test "PDF自動送信先は弥勒寺に固定する" do
    order_cycle = OrderCycle.new(
      year: 2030,
      month: 1,
      cycle_number: 1,
      deadline_at: Time.zone.local(2030, 1, 1, 12),
      arrival_date: Date.new(2030, 1, 10),
      tendo_send_at: Time.zone.local(2030, 1, 2, 9)
    )

    assert_predicate order_cycle, :valid?
    assert_equal "mirokuji", order_cycle.tendo_destination
  end

  test "送信日時を過ぎた未送信の注文サイクルを取得する" do
    order_cycle = OrderCycle.create!(
      year: 2030,
      month: 2,
      cycle_number: 2,
      deadline_at: Time.zone.local(2030, 2, 1, 12),
      arrival_date: Date.new(2030, 2, 10),
      tendo_send_at: 1.minute.ago
    )

    assert_includes OrderCycle.ready_for_tendo_submission, order_cycle
  end
end
