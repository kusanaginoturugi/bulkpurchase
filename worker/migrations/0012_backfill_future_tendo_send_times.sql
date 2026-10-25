UPDATE order_cycles
SET tendo_send_at = deadline_at,
    updated_at = CURRENT_TIMESTAMP
WHERE tendo_send_at IS NULL
  AND julianday(deadline_at) > julianday('now');
