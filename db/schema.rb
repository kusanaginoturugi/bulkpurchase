# frozen_string_literal: true

# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 20_260_429_020_000) do
  create_table 'item_variants', force: :cascade do |t|
    t.integer 'item_id', null: false
    t.string 'name', null: false
    t.integer 'display_order', default: 0, null: false
    t.boolean 'active', default: true, null: false
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index %w[item_id name], name: 'index_item_variants_on_item_id_and_name', unique: true
    t.index ['item_id'], name: 'index_item_variants_on_item_id'
  end

  create_table 'items', force: :cascade do |t|
    t.string 'code', null: false
    t.string 'name', null: false
    t.integer 'value', default: 0, null: false
    t.integer 'refund', default: 0, null: false
    t.string 'unit'
    t.string 'center_category', default: 'other', null: false
    t.string 'special_handling_type', default: 'none', null: false
    t.boolean 'active', default: true, null: false
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['code'], name: 'index_items_on_code', unique: true
    t.index ['name'], name: 'index_items_on_name'
  end

  create_table 'order_cycles', force: :cascade do |t|
    t.integer 'year', null: false
    t.integer 'month', null: false
    t.integer 'cycle_number', null: false
    t.datetime 'deadline_at', null: false
    t.date 'order_date', null: false
    t.date 'arrival_date', null: false
    t.string 'status', default: 'open', null: false
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index %w[year month], name: 'index_order_cycles_on_year_and_month', unique: true
  end

  create_table 'order_items', force: :cascade do |t|
    t.integer 'order_id', null: false
    t.integer 'item_id'
    t.integer 'item_variant_id'
    t.string 'item_code'
    t.string 'item_name', null: false
    t.string 'variant_name'
    t.integer 'quantity', null: false
    t.string 'unit', null: false
    t.text 'notes'
    t.integer 'sort_order', default: 0, null: false
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['item_id'], name: 'index_order_items_on_item_id'
    t.index ['item_variant_id'], name: 'index_order_items_on_item_variant_id'
    t.index ['order_id'], name: 'index_order_items_on_order_id'
  end

  create_table 'orders', force: :cascade do |t|
    t.integer 'user_id', null: false
    t.integer 'organization_id', null: false
    t.integer 'order_cycle_id', null: false
    t.string 'orderer_name', null: false
    t.string 'pickup_name', null: false
    t.string 'status', default: 'draft', null: false
    t.datetime 'submitted_at'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['order_cycle_id'], name: 'index_orders_on_order_cycle_id'
    t.index ['organization_id'], name: 'index_orders_on_organization_id'
    t.index %w[user_id order_cycle_id], name: 'index_orders_on_user_id_and_order_cycle_id', unique: true
    t.index ['user_id'], name: 'index_orders_on_user_id'
  end

  create_table 'organizations', force: :cascade do |t|
    t.string 'name', null: false
    t.boolean 'active', default: true, null: false
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.string 'code'
    t.index ['code'], name: 'index_organizations_on_code', unique: true
    t.index ['name'], name: 'index_organizations_on_name', unique: true
  end

  create_table 'sessions', force: :cascade do |t|
    t.integer 'user_id', null: false
    t.string 'ip_address'
    t.string 'user_agent'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['user_id'], name: 'index_sessions_on_user_id'
  end

  create_table 'users', force: :cascade do |t|
    t.string 'email_address', null: false
    t.string 'password_digest', null: false
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.string 'name', null: false
    t.integer 'organization_id', null: false
    t.string 'role', default: 'user', null: false
    t.boolean 'active', default: true, null: false
    t.index ['email_address'], name: 'index_users_on_email_address', unique: true
    t.index ['organization_id'], name: 'index_users_on_organization_id'
  end

  add_foreign_key 'item_variants', 'items'
  add_foreign_key 'order_items', 'item_variants'
  add_foreign_key 'order_items', 'items'
  add_foreign_key 'order_items', 'orders'
  add_foreign_key 'orders', 'order_cycles'
  add_foreign_key 'orders', 'organizations'
  add_foreign_key 'orders', 'users'
  add_foreign_key 'sessions', 'users'
  add_foreign_key 'users', 'organizations'
end
