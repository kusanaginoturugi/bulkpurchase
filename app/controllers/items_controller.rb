# frozen_string_literal: true

class ItemsController < ApplicationController
  def search
    query = params[:q].to_s.tr("０-９", "0-9").strip
    search_query = normalized_query(query)

    items = if query.present?
              escaped_query = ActiveRecord::Base.sanitize_sql_like(search_query)
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

  private

  def normalized_query(query)
    return "灶君護摩符" if so_kun_query?(query)

    query
  end

  def so_kun_query?(query)
    normalized = query.tr("竈", "灶")

    [
      "灶君護摩符",
      "そう君護摩符",
      "灶君北斗七星護摩符",
      "そう君北斗七星護摩符"
    ].any? { |name| normalized.include?(name) }
  end
end
