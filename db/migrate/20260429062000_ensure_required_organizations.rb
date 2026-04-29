# frozen_string_literal: true

class EnsureRequiredOrganizations < ActiveRecord::Migration[8.0]
  ORGANIZATIONS = {
    "31304" => "羽田",
    "31407" => "かながわ"
  }.freeze

  def up
    ORGANIZATIONS.each do |code, name|
      existing = Organization.find_by(code:) || Organization.find_by(name:)

      if existing
        existing.update!(code:, name:, active: true)
      else
        Organization.create!(code:, name:, active: true)
      end
    end
  end

  def down
    ORGANIZATIONS.each do |code, name|
      Organization.where(code:, name:).delete_all
    end
  end
end
