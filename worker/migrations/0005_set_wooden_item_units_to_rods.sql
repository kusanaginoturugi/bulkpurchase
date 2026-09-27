UPDATE items
SET unit = '本', updated_at = CURRENT_TIMESTAMP
WHERE name LIKE '%護摩木'
   OR name IN ('三期滅劫之霊木', '三會龍華之御柱', '八大明王如意棒', '龍樹滅業棒', '龍珠滅業棒');

UPDATE order_items
SET unit = '本'
WHERE item_name LIKE '%護摩木'
   OR item_name IN ('三期滅劫之霊木', '三會龍華之御柱', '八大明王如意棒', '龍樹滅業棒', '龍珠滅業棒');
