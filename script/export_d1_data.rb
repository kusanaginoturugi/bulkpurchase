# frozen_string_literal: true

# Rails の本番データを D1 に取り込める SQL として出力する。
# 実行例: RAILS_ENV=production bin/rails runner script/export_d1_data.rb > worker/import/rails-data.sql

require "json"

def sql(value)
  case value
  when nil then "NULL"
  when Numeric then value.to_s
  when true then "1"
  when false then "0"
  else "'#{value.to_s.gsub("'", "''")}'"
  end
end

puts "PRAGMA defer_foreign_keys = true;"
puts "DELETE FROM order_items;"
puts "DELETE FROM orders;"
puts "DELETE FROM users;"
puts "DELETE FROM item_variants;"
puts "DELETE FROM items;"
puts "DELETE FROM fellowships;"
puts "DELETE FROM order_cycles;"

Fellowship.available_to_users.order(:id).find_each do |fellowship|
  puts "INSERT INTO fellowships (id, code, name, active, created_at, updated_at) VALUES (#{[ fellowship.id, fellowship.code, fellowship.name, fellowship.active?, fellowship.created_at.iso8601, fellowship.updated_at.iso8601 ].map { |value| sql(value) }.join(", ")});"
end

Item.order(:id).find_each do |item|
  values = [ item.id, item.code, item.name, item.value, item.refund, item.unit, item.special_handling_type, item.active?, item.created_at.iso8601, item.updated_at.iso8601 ]
  puts "INSERT INTO items (id, code, name, value, refund, unit, special_handling_type, active, created_at, updated_at) VALUES (#{values.map { |value| sql(value) }.join(", ")});"
end

ItemVariant.order(:id).find_each do |variant|
  values = [ variant.id, variant.item_id, variant.name, variant.display_order, variant.active? ]
  puts "INSERT INTO item_variants (id, item_id, name, display_order, active) VALUES (#{values.map { |value| sql(value) }.join(", ")});"
end

OrderCycle.order(:id).find_each do |cycle|
  values = [ cycle.id, cycle.year, cycle.month, cycle.deadline_at.iso8601, cycle.order_date, cycle.arrival_date, cycle.status, cycle.tendo_send_at&.iso8601, cycle.tendo_sent_at&.iso8601, cycle.tendo_email_sent_at&.iso8601, cycle.tendo_send_error, cycle.created_at.iso8601, cycle.updated_at.iso8601 ]
  puts "INSERT INTO order_cycles (id, year, month, deadline_at, order_date, arrival_date, status, tendo_send_at, tendo_sent_at, tendo_email_sent_at, tendo_send_error, created_at, updated_at) VALUES (#{values.map { |value| sql(value) }.join(", ")});"
end

User.where(fellowship: Fellowship.available_to_users).order(:id).find_each do |user|
  values = [ user.id, user.authentik_subject, user.email_address, user.name, user.fellowship_id, user.role, user.active?, user.authentik_groups.to_s, user.created_at.iso8601, user.updated_at.iso8601 ]
  puts "INSERT INTO users (id, authentik_subject, email, name, fellowship_id, role, active, authentik_groups, created_at, updated_at) VALUES (#{values.map { |value| sql(value) }.join(", ")});"
end

Order.where(fellowship: Fellowship.available_to_users).order(:id).find_each do |order|
  values = [ order.id, order.order_cycle_id, order.fellowship_id, order.user_id, order.orderer_name, order.pickup_name, order.status, order.submitted_at&.iso8601, order.auto_generated?, order.created_at.iso8601, order.updated_at.iso8601 ]
  puts "INSERT INTO orders (id, order_cycle_id, fellowship_id, user_id, orderer_name, pickup_name, status, submitted_at, auto_generated, created_at, updated_at) VALUES (#{values.map { |value| sql(value) }.join(", ")});"
end

OrderItem.joins(order: :fellowship).merge(Fellowship.available_to_users).order(:id).find_each do |item|
  values = [ item.id, item.order_id, item.item_id, item.item_code, item.item_name, item.variant_name, item.quantity, item.unit, item.sort_order ]
  puts "INSERT INTO order_items (id, order_id, item_id, item_code, item_name, variant_name, quantity, unit, sort_order) VALUES (#{values.map { |value| sql(value) }.join(", ")});"
end
