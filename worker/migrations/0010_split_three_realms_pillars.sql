UPDATE items
SET name = '有気界之御柱', updated_at = CURRENT_TIMESTAMP
WHERE code = '120001';

INSERT OR IGNORE INTO items (code, name, value, refund, unit, special_handling_type, active)
VALUES
  ('120003', '気天界之御柱', 2000, 300, '本', 'none', 1),
  ('120004', '象天界之御柱', 2000, 300, '本', 'none', 1),
  ('120005', '地獄界之御柱', 2000, 300, '本', 'none', 1),
  ('120006', '地上餓鬼界之御柱', 2000, 300, '本', 'none', 1);
