UPDATE items SET unit = '枚', updated_at = CURRENT_TIMESTAMP WHERE unit = '個';
UPDATE order_items SET unit = '枚' WHERE unit = '個';
