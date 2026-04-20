# frozen_string_literal: true

class CurrentOrdersController < ApplicationController
  before_action :set_order_cycle
  before_action :set_order

  def show
    @organizations = Organization.active.order(:name)
    build_blank_rows if @order.order_items.empty?
  end

  def create
    save_order
  end

  def update
    save_order
  end

  private

  def set_order_cycle
    @order_cycle = OrderCycle.current_for_user
  end

  def set_order
    @order = if @order_cycle
               current_user.orders
                           .includes(order_items: %i[item item_variant])
                           .find_or_initialize_by(order_cycle: @order_cycle)
                           .tap do |order|
                 order.organization ||= current_user.organization
                 order.orderer_name ||= current_user.name
               end
    else
               current_user.orders.new
    end
  end

  def build_blank_rows(count = 1)
    count.times do |index|
      @order.order_items.build(sort_order: index)
    end
  end

  def save_order
    unless @order_cycle
      redirect_to root_path, alert: "受付中の注文サイクルがありません。"
      return
    end

    unless @order.editable_by_user?
      redirect_to current_order_path, alert: "この注文はすでに送信済みのため編集できません。"
      return
    end

    @order.assign_attributes(order_params)
    @order.user = current_user
    @order.organization = current_user.organization
    @order.order_cycle = @order_cycle

    if params[:commit_action] == "submit"
      @order.mark_submitted!
    elsif @order.status.blank?
      @order.status = "draft"
    end

    if @order.save
      message = params[:commit_action] == "submit" ? "注文を提出しました。" : "注文を保存しました。"
      redirect_to current_order_path, notice: message
    else
      @organizations = Organization.active.order(:name)
      build_blank_rows(1) if @order.order_items.empty?
      render :show, status: :unprocessable_entity
    end
  end

  def order_params
    params.require(:order).permit(
      :orderer_name,
      :pickup_name,
      order_items_attributes: %i[
        id item_id item_variant_id item_code item_name variant_name quantity unit notes sort_order _destroy
      ]
    )
  end
end
