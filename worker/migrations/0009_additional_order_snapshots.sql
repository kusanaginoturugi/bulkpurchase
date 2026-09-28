CREATE TABLE additional_order_snapshots (
  order_cycle_id INTEGER NOT NULL,
  fellowship_id INTEGER NOT NULL,
  item_key TEXT NOT NULL,
  quantity INTEGER NOT NULL,
  PRIMARY KEY (order_cycle_id, fellowship_id, item_key)
);
