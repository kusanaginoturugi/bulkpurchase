# frozen_string_literal: true

require "test_helper"

class MyououinRegularOrderTest < ActiveSupport::TestCase
  test "2月の注文サイクルへ聖明王院の定期注文を登録する" do
    fellowship = Fellowship.create!(code: "99300", name: "聖明王院", active: false, enabled: false)
    order_cycle = OrderCycle.create!(
      year: 2031,
      month: 2,
      cycle_number: 2,
      deadline_at: Time.zone.local(2031, 1, 25, 23, 59),
      arrival_date: Date.new(2031, 2, 10)
    )

    MyououinRegularOrder.register(order_cycle)

    order = Order.find_by!(order_cycle: order_cycle, fellowship: fellowship)
    assert_predicate order, :auto_generated?
    assert_predicate order, :submitted?
    assert_equal "聖明王院", order.orderer_name
    assert_equal "", order.pickup_name
    assert_equal [ [ "月例用大光明御柱", 18, "本" ] ], order.order_items.pluck(:item_name, :quantity, :unit)
  end

  test "対象外の月には定期注文を登録しない" do
    order_cycle = OrderCycle.create!(
      year: 2031,
      month: 3,
      cycle_number: 3,
      deadline_at: Time.zone.local(2031, 2, 25, 23, 59),
      arrival_date: Date.new(2031, 3, 10)
    )

    assert_no_difference "Order.count" do
      MyououinRegularOrder.register(order_cycle)
    end
  end
end
