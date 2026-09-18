# frozen_string_literal: true

class CorrectOctober2026ArrivalDate < ActiveRecord::Migration[8.1]
  def up
    OrderCycle.where(year: 2026, month: 10).update_all(arrival_date: Date.new(2026, 10, 10))
  end

  def down
    OrderCycle.where(year: 2026, month: 10).update_all(arrival_date: Date.new(2026, 10, 11))
  end
end
