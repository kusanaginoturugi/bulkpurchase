PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS fellowships (
  id INTEGER PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL UNIQUE,
  active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY,
  authentik_subject TEXT UNIQUE,
  email TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  fellowship_id INTEGER NOT NULL REFERENCES fellowships(id),
  role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'admin')),
  active INTEGER NOT NULL DEFAULT 1,
  authentik_groups TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS sessions (
  id TEXT PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  csrf_token TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS items (
  id INTEGER PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  value INTEGER NOT NULL DEFAULT 0,
  refund INTEGER NOT NULL DEFAULT 0,
  unit TEXT NOT NULL,
  special_handling_type TEXT NOT NULL DEFAULT 'none',
  active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS item_variants (
  id INTEGER PRIMARY KEY,
  item_id INTEGER NOT NULL REFERENCES items(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  display_order INTEGER NOT NULL DEFAULT 0,
  active INTEGER NOT NULL DEFAULT 1,
  UNIQUE(item_id, name)
);

CREATE TABLE IF NOT EXISTS order_cycles (
  id INTEGER PRIMARY KEY,
  year INTEGER NOT NULL,
  month INTEGER NOT NULL CHECK (month BETWEEN 1 AND 12),
  deadline_at TEXT NOT NULL,
  order_date TEXT NOT NULL,
  arrival_date TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'closed', 'sent')),
  tendo_send_at TEXT,
  tendo_sent_at TEXT,
  tendo_email_sent_at TEXT,
  tendo_send_error TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(year, month)
);

CREATE TABLE IF NOT EXISTS orders (
  id INTEGER PRIMARY KEY,
  order_cycle_id INTEGER NOT NULL REFERENCES order_cycles(id) ON DELETE CASCADE,
  fellowship_id INTEGER NOT NULL REFERENCES fellowships(id),
  user_id INTEGER NOT NULL REFERENCES users(id),
  orderer_name TEXT NOT NULL,
  pickup_name TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'submitted')),
  submitted_at TEXT,
  auto_generated INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(order_cycle_id, fellowship_id)
);

CREATE TABLE IF NOT EXISTS order_items (
  id INTEGER PRIMARY KEY,
  order_id INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  item_id INTEGER REFERENCES items(id),
  item_code TEXT,
  item_name TEXT NOT NULL,
  variant_name TEXT,
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  unit TEXT NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS index_orders_cycle ON orders(order_cycle_id);
CREATE INDEX IF NOT EXISTS index_orders_fellowship ON orders(fellowship_id);
CREATE INDEX IF NOT EXISTS index_order_items_order ON order_items(order_id);
CREATE INDEX IF NOT EXISTS index_sessions_expiry ON sessions(expires_at);

INSERT OR IGNORE INTO fellowships (code, name) VALUES
  ('31101', '埼玉'),
  ('31201', '千葉'),
  ('31303', '大江戸'),
  ('31304', '羽田'),
  ('31305', 'お台場'),
  ('31407', 'かながわ'),
  ('31901', '山梨'),
  ('32204', '富士山'),
  ('32205', '駿天');
