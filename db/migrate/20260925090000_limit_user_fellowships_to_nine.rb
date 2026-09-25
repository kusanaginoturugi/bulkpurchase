# frozen_string_literal: true

class LimitUserFellowshipsToNine < ActiveRecord::Migration[8.1]
  FELLOWSHIPS = Fellowship::MANAGED_FELLOWSHIPS.freeze

  def up
    FELLOWSHIPS.each do |code, name|
      fellowship = Fellowship.find_or_initialize_by(code: code)
      fellowship.assign_attributes(name: name, active: true, enabled: true)
      fellowship.save!
    end

    Fellowship.where.not(code: FELLOWSHIPS.keys).update_all(active: false, enabled: false)
  end

  def down
    Fellowship.where(code: FELLOWSHIPS.keys).update_all(enabled: false)
  end
end
