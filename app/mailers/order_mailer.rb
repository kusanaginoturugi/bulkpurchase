class OrderMailer < ApplicationMailer
  def confirmation(order)
    @order = order
    mail(to: @order.user.email_address, subject: "【聖明王院】注文内容の確認")
  end

  def reminder(order)
    @order = order
    mail(to: @order.user.email_address, subject: "【聖明王院】注文日のご案内")
  end

  def summary(order_cycle, recipients)
    @order_cycle = order_cycle
    attachments["order_summary_#{order_cycle.year}_#{order_cycle.month}.pdf"] = OrderSheetPdf.new(order_cycle).render
    mail(to: recipients, subject: "【聖明王院】#{order_cycle.label} 集計表")
  end
end
