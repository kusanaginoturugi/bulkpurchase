CREATE TABLE IF NOT EXISTS tendo_send_logs (
  id INTEGER PRIMARY KEY,
  order_cycle_id INTEGER NOT NULL REFERENCES order_cycles(id) ON DELETE CASCADE,
  channel TEXT NOT NULL CHECK (channel IN ('tendo', 'email')),
  trigger_type TEXT NOT NULL CHECK (trigger_type IN ('automatic', 'manual')),
  status TEXT NOT NULL CHECK (status IN ('success', 'failed')),
  detail TEXT,
  sent_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS index_tendo_send_logs_cycle ON tendo_send_logs(order_cycle_id, sent_at DESC);

INSERT INTO tendo_send_logs (order_cycle_id, channel, trigger_type, status, detail, sent_at)
SELECT id, 'tendo', 'automatic', 'success', '送信履歴の記録開始前に送信済み', tendo_sent_at
FROM order_cycles
WHERE tendo_sent_at IS NOT NULL;
