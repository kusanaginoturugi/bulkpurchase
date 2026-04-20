# frozen_string_literal: true

class OrdersController < ApplicationController
  def index
    @orders = scoped_orders.includes(:order_cycle, :organization, :user).order(created_at: :desc)
    @admin_view = current_user.admin?
  end

  def show
    @order = scoped_orders.includes(:organization, :user, :order_cycle,
                                    order_items: %i[item item_variant]).find(params[:id])
    @admin_view = current_user.admin?
  end

  private

  def scoped_orders
    current_user.admin? ? Order.all : current_user.orders
  end
end
