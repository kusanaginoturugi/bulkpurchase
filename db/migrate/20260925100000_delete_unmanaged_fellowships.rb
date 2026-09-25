# frozen_string_literal: true

class DeleteUnmanagedFellowships < ActiveRecord::Migration[8.1]
  FELLOWSHIP_CODES = Fellowship::MANAGED_FELLOWSHIPS.keys.freeze

  def up
    fellowship_ids = Fellowship.where.not(code: FELLOWSHIP_CODES).or(Fellowship.where(code: nil)).pluck(:id)
    return if fellowship_ids.empty?

    Order.where(fellowship_id: fellowship_ids).find_each(&:destroy!)
    User.where(fellowship_id: fellowship_ids).find_each(&:destroy!)
    Fellowship.where(id: fellowship_ids).destroy_all
  end

  def down
    # 削除した伝道会と注文は復元できない。
  end
end
