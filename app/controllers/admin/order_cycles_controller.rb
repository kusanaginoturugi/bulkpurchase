# frozen_string_literal: true

module Admin
  class OrderCyclesController < BaseController
    before_action :set_order_cycle, only: %i[show edit update]

    def index
      @order_cycles = OrderCycle.recent_first
    end

    def show
      @orders = @order_cycle.orders.includes(:organization, :user, :order_items)
      respond_to do |format|
        format.html
        format.pdf do
          send_data OrderSheetPdf.new(@order_cycle).render,
                    filename: "#{@order_cycle.label}_一括道具注文書.pdf",
                    type: "application/pdf",
                    disposition: "attachment"
        end
      end
    end

    def create
      @order_cycle = OrderCycle.new(order_cycle_params)

      if @order_cycle.save
        redirect_to admin_order_cycles_path, notice: "注文サイクルを登録しました。"
      else
        @order_cycles = OrderCycle.recent_first
        render :index, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @order_cycle.update(order_cycle_params)
        redirect_to admin_order_cycles_path, notice: "注文サイクルを更新しました。"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_order_cycle
      @order_cycle = OrderCycle.find(params[:id])
    end

    def order_cycle_params
      params.require(:order_cycle).permit(:year, :month, :deadline_at, :arrival_date, :status)
    end
  end
end
