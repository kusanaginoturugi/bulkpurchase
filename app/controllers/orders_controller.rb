class OrdersController < ApplicationController
  def index
    @orders = current_user.orders.includes(:order_cycle, :organization).order(created_at: :desc)
  end

  def show
    @order = current_user.orders.includes(order_items: [ :item, :item_variant ]).find(params[:id])
  end
end
