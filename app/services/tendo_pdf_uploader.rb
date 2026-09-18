# frozen_string_literal: true

require "net/http"
require "securerandom"

class TendoPdfUploader
  UPLOAD_URI = URI("https://tendo.aa0.netvolante.jp/res.php")

  def initialize(order_cycle)
    @order_cycle = order_cycle
  end

  def call
    boundary = "----Bulkpurchase#{SecureRandom.hex(16)}"
    request = Net::HTTP::Post.new(UPLOAD_URI)
    request["Content-Type"] = "multipart/form-data; boundary=#{boundary}"
    request.body = multipart_body(boundary)

    response = Net::HTTP.start(UPLOAD_URI.host, UPLOAD_URI.port, use_ssl: true) do |http|
      http.request(request)
    end

    return if response.is_a?(Net::HTTPSuccess)

    raise "天道へのPDF送信に失敗しました（HTTP #{response.code}）"
  end

  private

  def multipart_body(boundary)
    fields = {
      "name" => ENV.fetch("TENDO_SENDER_NAME", "尾ノ上裕美"),
      "dendokai" => ENV.fetch("TENDO_FELLOWSHIP_NAME", "泉珠山梨伝道会"),
      "title" => "#{@order_cycle.label} 道具一括注文書",
      "text" => "#{@order_cycle.label}の道具一括注文書を送信します。",
      @order_cycle.tendo_destination => "送信"
    }
    parts = fields.map { |name, value| field_part(boundary, name, value) }
    parts << file_part(boundary)
    parts << "--#{boundary}--\r\n".b
    parts.join
  end

  def field_part(boundary, name, value)
    ("--#{boundary}\r\n" \
      "Content-Disposition: form-data; name=\"#{name}\"\r\n\r\n" \
      "#{value}\r\n").b
  end

  def file_part(boundary)
    filename = "#{@order_cycle.label}_一括道具注文書.pdf"
    headers = ("--#{boundary}\r\n" \
      "Content-Disposition: form-data; name=\"up_file[]\"; filename=\"#{filename}\"\r\n" \
      "Content-Type: application/pdf\r\n\r\n").b

    headers + OrderSheetPdf.new(@order_cycle).render + "\r\n".b
  end
end
