# frozen_string_literal: true

class OrderSheetPdf
  def initialize(order_cycle)
    @order_cycle = order_cycle
  end

  def render
    Prawn::Document.new(page_size: "A4", margin: 36) do |pdf|
      pdf.text "聖明王院道具一括注文", size: 18, style: :bold
      pdf.move_down 8
      pdf.text "#{@order_cycle.label} / 必着日 #{@order_cycle.arrival_date}"
      pdf.move_down 20

      aggregated_rows.each do |row|
        pdf.text row, size: 10
      end
    end.render
  end

  private

  def aggregated_rows
    organizations = @order_cycle.orders.includes(:organization).map(&:organization).uniq.sort_by(&:name)
    grouped = Hash.new { |hash, key| hash[key] = Hash.new(0) }

    @order_cycle.orders.includes(order_items: :item).find_each do |order|
      order.order_items.each do |order_item|
        grouped[order_item.output_name][order.organization.name] += order_item.quantity
      end
    end

    grouped.map do |name, quantities|
      detail = organizations.map do |organization|
        "#{organization.name}: #{quantities[organization.name]}"
      end.join(" / ")
      "#{name} | #{detail} | 合計: #{quantities.values.sum}"
    end
  end
end
