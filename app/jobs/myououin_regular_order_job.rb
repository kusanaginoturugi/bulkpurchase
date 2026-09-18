# frozen_string_literal: true

class MyououinRegularOrderJob < ApplicationJob
  queue_as :default

  def perform
    OrderCycle.where(month: MyououinRegularOrder::MONTHS).where.not(status: :sent).find_each do |order_cycle|
      MyououinRegularOrder.register(order_cycle)
    end
  end
end
