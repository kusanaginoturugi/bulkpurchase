# frozen_string_literal: true

class RestrictTendoSubmissionsToMirokuji < ActiveRecord::Migration[8.1]
  def up
    OrderCycle.where.not(tendo_send_at: nil).update_all(tendo_destination: "mirokuji")
  end

  def down; end
end
