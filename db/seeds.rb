# frozen_string_literal: true

require 'csv'

def infer_unit(name)
  return '組' if %w[白陽八卦符 みろく鵺符].any? { |keyword| name.include?(keyword) }
  return '本' if %w[護摩木 御柱 棒].any? { |keyword| name.include?(keyword) }
  return '枚' if %w[札 符 人型 銭型 金紙 銀紙 暦].any? { |keyword| name.include?(keyword) }

  '個'
end

organization_codes = {
  '埼玉' => '31101',
  '千葉' => '31201',
  '大江戸' => '31303',
  'お台場' => '31305',
  '山梨' => '31901',
  '富士山' => '32204',
  '駿天' => '32205',
  '聖明王院' => '99300'
}

organizations = organization_codes.each_with_object({}) do |(name, code), result|
  Organization.find_or_initialize_by(name:).tap do |organization|
    organization.code = code
    organization.active = true
    organization.save!
    result[name] = organization
  end
end

admin = User.find_or_initialize_by(email_address: 'admin@example.com')
admin.assign_attributes(
  name: '管理者',
  password: 'password',
  password_confirmation: 'password',
  organization: organizations.fetch('富士山'),
  role: :admin,
  active: true
)
admin.save!

sample_user = User.find_or_initialize_by(email_address: 'member@example.com')
sample_user.assign_attributes(
  name: 'サンプル会員',
  password: 'password',
  password_confirmation: 'password',
  organization: organizations.fetch('山梨'),
  role: :user,
  active: true
)
sample_user.save!

CSV.foreach(Rails.root.join('items.csv'), headers: true) do |row|
  item = Item.find_or_initialize_by(code: row.fetch('code'))
  item.assign_attributes(
    name: row.fetch('name'),
    value: row.fetch('value').to_i,
    refund: row.fetch('refund').to_i,
    unit: infer_unit(row.fetch('name')),
    center_category: :other,
    special_handling_type: row.fetch('name').include?('白陽八卦符') ? :hakuyo_hakke : :none,
    active: true
  )
  item.save!
end

hakke = Item.find_by(name: '白陽八卦符')
if hakke
  %w[無地 有気復命].each_with_index do |name, index|
    hakke.item_variants.find_or_create_by!(name:) do |variant|
      variant.display_order = index
      variant.active = true
    end
  end
end

OrderCycle.find_or_create_by!(year: Date.current.year, month: Date.current.month) do |order_cycle|
  order_cycle.cycle_number = Date.current.month
  order_cycle.deadline_at = Time.current.end_of_day
  order_cycle.order_date = Date.current + 1.week
  order_cycle.arrival_date = Date.current + 2.weeks
  order_cycle.status = :open
end
