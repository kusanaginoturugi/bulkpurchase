module Admin
  class OrdersController < BaseController
    def index
      @orders = Order.includes(:organization, :user, :order_cycle).order(created_at: :desc)
    end

    def show
      @order = Order.includes(:organization, :user, :order_cycle, order_items: [ :item, :item_variant ]).find(params[:id])
    end
  end
end
