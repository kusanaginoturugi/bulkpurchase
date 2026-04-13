class ItemsController < ApplicationController
  def search
    query = params[:q].to_s.strip

    items = if query.present?
      Item.active
        .where("code LIKE :q OR name LIKE :q", q: "#{query}%")
        .includes(:item_variants)
        .order(:code)
        .limit(20)
    else
      Item.none
    end

    render json: items.map { |item|
      {
        id: item.id,
        code: item.code,
        name: item.name,
        unit: item.unit,
        special_handling_type: item.special_handling_type,
        variants: item.item_variants.active.map { |variant|
          { id: variant.id, name: variant.name }
        }
      }
    }
  end
end
