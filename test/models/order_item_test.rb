# frozen_string_literal: true

require "test_helper"

class OrderItemTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "道具マスタの単位で保存する" do
    item = Item.new(code: "201002", name: "白陽八卦符", unit: "組")

    order_item = OrderItem.new(
      order: Order.new,
      item: item,
      item_name: item.name,
      quantity: 1,
      unit: "枚"
    )

    assert_predicate order_item, :valid?
    assert_equal "組", order_item.unit
  end
end
