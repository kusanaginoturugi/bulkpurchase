UPDATE items
SET name = CASE code
  WHEN '120001' THEN '有気界平定之御柱'
  WHEN '120003' THEN '気天界平定之御柱'
  WHEN '120004' THEN '象天界平定之御柱'
  WHEN '120005' THEN '地獄界平定之御柱'
  WHEN '120006' THEN '地上餓鬼界平定之御柱'
END,
updated_at = CURRENT_TIMESTAMP
WHERE code IN ('120001', '120003', '120004', '120005', '120006');
