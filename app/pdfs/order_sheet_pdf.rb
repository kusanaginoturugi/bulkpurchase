# frozen_string_literal: true

class OrderSheetPdf
  FONT_PATHS = [
    Rails.root.join("app/assets/fonts/NotoSansJP-Regular.ttf").to_s,
    "/System/Library/Fonts/ヒラギノ角ゴシック W0.ttc",
    "/System/Library/Fonts/ヒラギノ丸ゴ ProN W4.ttc",
    "/System/Library/Fonts/AppleSDGothicNeo.ttc",
    "/System/Library/Fonts/Supplemental/AppleGothic.ttf"
  ].freeze
  WEEKDAYS = %w[日 月 火 水 木 金 土].freeze

  def initialize(order_cycle)
    @order_cycle = order_cycle
  end

  def render
    Prawn::Document.new(page_size: "A4", margin: [ 24, 28, 24, 28 ]) do |pdf|
      setup_font(pdf)
      draw_header(pdf)
      draw_table(pdf)
    end.render
  end

  private

  def setup_font(pdf)
    font_path = FONT_PATHS.find { |path| File.exist?(path) }
    return unless font_path

    pdf.font_families.update("Japanese" => { normal: font_path, bold: font_path })
    pdf.font("Japanese")
  end

  def draw_header(pdf)
    pdf.text "※#{month_day_with_weekday(@order_cycle.arrival_date)}までに弥勒大仏殿着でお願いします。",
             size: 17,
             style: :bold,
             align: :center
    pdf.move_down 4
    pdf.text "聖明王院　一括道具注文書", size: 21, align: :center
    pdf.move_down 8
    pdf.text "【注文日】 #{japanese_era_date(@order_cycle.order_date)}", size: 14
    pdf.move_down 6
  end

  def draw_table(pdf)
    rows = aggregated_rows
    organizations = submitted_organizations
    name_width = 128
    total_width = 52
    quantity_width = (pdf.bounds.width - name_width - total_width) / [ organizations.size, 1 ].max
    row_height = 44

    draw_row(pdf, [ "", *organizations.map(&:name), "合計" ], [ name_width, *([ quantity_width ] * organizations.size), total_width ], row_height, header: true)

    rows.each do |row|
      pdf.start_new_page if pdf.cursor < row_height + 28

      cells = [
        formatted_item_name(row[:name]),
        *organizations.map { |organization| row[:quantities][organization.id].presence || "" },
        row[:total]
      ]
      draw_row(pdf, cells, [ name_width, *([ quantity_width ] * organizations.size), total_width ], row_height)
    end
  end

  def draw_row(pdf, cells, widths, height, header: false)
    x = pdf.bounds.left
    y = pdf.cursor

    cells.each_with_index do |cell, index|
      width = widths[index]
      pdf.stroke_rectangle [ x, y ], width, height
      number_cell = !header && index.positive?
      text_width = number_cell ? [ width * 0.5, 34 ].max : width - 8
      text_x = number_cell ? x + ((width - text_width) / 2.0) : x + 4

      pdf.text_box cell.to_s,
                   at: [ text_x, y - 6 ],
                   width: text_width,
                   height: height - 8,
                   size: header ? 16 : 15,
                   align: number_cell ? :right : :center,
                   valign: :center,
                   overflow: :shrink_to_fit,
                   min_font_size: 10
      x += width
    end

    pdf.move_down height
  end

  def submitted_organizations
    @submitted_organizations ||= @order_cycle.orders
                                         .submitted
                                         .includes(:organization)
                                         .map(&:organization)
                                         .uniq
                                         .sort_by { |organization| [ organization.code.to_s, organization.name ] }
  end

  def aggregated_rows
    grouped = {}

    @order_cycle.orders.submitted.includes(:organization, order_items: :item).find_each do |order|
      order.order_items.each do |order_item|
        key = [ order_item.item_code.to_s, order_item.output_name, order_item.unit.to_s ]
        grouped[key] ||= {
          code: order_item.item_code.to_s,
          name: order_item.output_name,
          quantities: Hash.new(0)
        }
        grouped[key][:quantities][order.organization_id] += order_item.quantity
      end
    end

    grouped.values
           .sort_by { |row| [ row[:code], row[:name] ] }
           .map { |row| row.merge(total: row[:quantities].values.sum) }
  end

  def formatted_item_name(name)
    name.to_s
        .gsub(%r{\s*/\s*}, "\n")
        .gsub(/\s*([（(])/, "\n\\1")
        .gsub(/・\s*/, "・\n")
  end

  def month_day_with_weekday(date)
    "#{date.month}月#{date.day}日(#{WEEKDAYS[date.wday]})"
  end

  def japanese_era_date(date)
    return I18n.l(date) if date < Date.new(2019, 5, 1)

    year = date.year - 2018
    era_year = year == 1 ? "元" : year.to_s
    "令和#{era_year}年#{date.month}月#{date.day}日"
  end
end
