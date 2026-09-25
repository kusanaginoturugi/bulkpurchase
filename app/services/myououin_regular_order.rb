# frozen_string_literal: true

class MyououinRegularOrder
  MONTHS = [ 2, 8 ].freeze
  FELLOWSHIP_NAME = "聖明王院"
  SYSTEM_EMAIL = "regular-order@bulkpurchase.showway.biz"
  ITEM_NAME = "月例用大光明御柱"
  QUANTITY = 18
  UNIT = "本"

  def self.register(order_cycle)
    new(order_cycle).register
  end

  def initialize(order_cycle)
    @order_cycle = order_cycle
  end

  def register
    return unless MONTHS.include?(@order_cycle.month)

    fellowship = Fellowship.find_by!(name: FELLOWSHIP_NAME)
    order = Order.find_or_initialize_by(order_cycle: @order_cycle, fellowship: fellowship)
    return if order.persisted? && !order.auto_generated?

    order.assign_attributes(
      user: system_user(fellowship),
      orderer_name: FELLOWSHIP_NAME,
      pickup_name: "",
      status: :submitted,
      submitted_at: order.submitted_at || Time.current,
      auto_generated: true
    )
    order.order_items = [
      OrderItem.new(item_name: ITEM_NAME, quantity: QUANTITY, unit: UNIT, sort_order: 0)
    ]
    order.save!
  end

  private

  def system_user(fellowship)
    User.find_or_initialize_by(email_address: SYSTEM_EMAIL).tap do |user|
      user.assign_attributes(name: FELLOWSHIP_NAME, fellowship: fellowship, role: :user, active: true)
      user.password = SecureRandom.base58(32) if user.new_record?
      user.save!
    end
  end
end
