# frozen_string_literal: true

class ItemsController < ApplicationController
  def search
    query = params[:q].to_s.tr("０-９", "0-9").strip

    items = if query.present?
              escaped_query = ActiveRecord::Base.sanitize_sql_like(query)
              Item.active
                  .managed
                  .where("code LIKE :q OR name LIKE :q", q: "#{escaped_query}%")
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
