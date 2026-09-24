# frozen_string_literal: true

class AddTendoEmailSentAtToOrderCycles < ActiveRecord::Migration[8.1]
  def up
    add_column :order_cycles, :tendo_email_sent_at, :datetime
    execute <<~SQL.squish
      UPDATE order_cycles
      SET tendo_email_sent_at = tendo_sent_at
      WHERE tendo_sent_at IS NOT NULL
    SQL
  end

  def down
    remove_column :order_cycles, :tendo_email_sent_at
  end
end
