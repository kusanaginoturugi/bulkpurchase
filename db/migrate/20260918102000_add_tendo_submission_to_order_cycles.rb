# frozen_string_literal: true

class AddTendoSubmissionToOrderCycles < ActiveRecord::Migration[8.1]
  def change
    add_column :order_cycles, :tendo_send_at, :datetime
    add_column :order_cycles, :tendo_destination, :string
    add_column :order_cycles, :tendo_sent_at, :datetime
    add_column :order_cycles, :tendo_send_error, :text
  end
end
