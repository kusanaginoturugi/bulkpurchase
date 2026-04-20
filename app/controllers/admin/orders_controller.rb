module Admin
  class OrdersController < BaseController
    before_action :set_order, only: [ :show, :edit, :update ]
    before_action :load_organizations, only: [ :edit, :update ]

    def index
      @orders = Order.includes(:organization, :user, :order_cycle).order(created_at: :desc)
    end

    def show
    end

    def edit
      build_blank_rows if @order.order_items.empty?
    end

    def update
      @order.assign_attributes(order_params)

      if params[:commit_action] == "submit"
        @order.mark_submitted!
      elsif @order.status.blank?
        @order.status = "draft"
      end

      if @order.save
        redirect_to admin_order_path(@order), notice: "注文を更新しました。"
      else
        build_blank_rows(1) if @order.order_items.empty?
        render :edit, status: :unprocessable_entity
      end
    end

    private
      def set_order
        @order = Order.includes(:organization, :user, :order_cycle, order_items: [ :item, :item_variant ]).find(params[:id])
      end

      def load_organizations
        @organizations = Organization.active.order(:name)
      end

      def build_blank_rows(count = 1)
        count.times do |index|
          @order.order_items.build(sort_order: @order.order_items.size + index)
        end
      end

      def order_params
        params.require(:order).permit(
          :orderer_name,
          :pickup_name,
          :organization_id,
          :status,
          order_items_attributes: [
            :id, :item_id, :item_variant_id, :item_code, :item_name, :variant_name, :quantity, :unit, :notes, :sort_order, :_destroy
          ]
        )
      end
  end
end
