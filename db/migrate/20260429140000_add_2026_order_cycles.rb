# frozen_string_literal: true

class Add2026OrderCycles < ActiveRecord::Migration[8.0]
  CYCLES = [
    { month: 6, deadline: [ 5, 31 ], arrival: [ 6, 13 ] },
    { month: 7, deadline: [ 6, 28 ], arrival: [ 7, 11 ] },
    { month: 8, deadline: [ 7, 26 ], arrival: [ 8, 8 ] },
    { month: 9, deadline: [ 8, 30 ], arrival: [ 9, 12 ] },
    { month: 10, deadline: [ 9, 27 ], arrival: [ 10, 11 ] },
    { month: 11, deadline: [ 10, 25 ], arrival: [ 11, 7 ] },
    { month: 12, deadline: [ 11, 29 ], arrival: [ 12, 12 ] }
  ].freeze

  def up
    CYCLES.each do |cycle|
      order_cycle = OrderCycle.find_or_initialize_by(year: 2026, month: cycle.fetch(:month))
      order_cycle.assign_attributes(
        cycle_number: cycle.fetch(:month),
        deadline_at: deadline_at(*cycle.fetch(:deadline)),
        arrival_date: arrival_date(*cycle.fetch(:arrival)),
        status: :open
      )
      order_cycle.save!
    end
  end

  def down
    OrderCycle.where(year: 2026, month: CYCLES.map { |cycle| cycle.fetch(:month) }).delete_all
  end

  private

  def deadline_at(month, day)
    Time.zone.local(2026, month, day, 23, 59)
  end

  def arrival_date(month, day)
    Date.new(2026, month, day)
  end
end
