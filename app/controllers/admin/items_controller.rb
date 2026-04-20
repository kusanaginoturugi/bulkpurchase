# frozen_string_literal: true

module Admin
  class ItemsController < BaseController
    before_action :set_item, only: %i[edit update]

    def index
      @items = Item.includes(:item_variants).order(:code)
      @item = Item.new(active: true, center_category: :other, special_handling_type: :none)
    end

    def create
      @item = Item.new(item_params)

      if @item.save
        sync_variants
        redirect_to admin_items_path, notice: "道具を登録しました。"
      else
        @items = Item.includes(:item_variants).order(:code)
        render :index, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @item.update(item_params)
        sync_variants
        redirect_to admin_items_path, notice: "道具を更新しました。"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_item
      @item = Item.includes(:item_variants).find(params[:id])
    end

    def item_params
      params.require(:item).permit(:code, :name, :value, :refund, :unit, :center_category, :special_handling_type,
                                   :active)
    end

    def sync_variants
      return unless params[:variant_names]

      submitted_names = params[:variant_names].split("\n").map(&:strip).reject(&:blank?)

      @item.item_variants.where.not(name: submitted_names).destroy_all

      submitted_names.each_with_index do |name, index|
        variant = @item.item_variants.find_or_initialize_by(name:)
        variant.display_order = index
        variant.active = true
        variant.save!
      end
    end
  end
end
