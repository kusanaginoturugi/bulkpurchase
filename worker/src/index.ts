import { Hono, type Context } from "hono";
import { deleteCookie, getCookie, setCookie } from "hono/cookie";

import { createOrderPdf } from "./pdf";
import type { Env, Fellowship, Item, SessionUser } from "./types";
import { renderPage } from "./ui";

type AppBindings = { Bindings: Env; Variables: { user: SessionUser } };

const app = new Hono<AppBindings>();
const managedCodes = ["31101", "31201", "31303", "31304", "31305", "31407", "31901", "32204", "32205", "99300"];
const fixedUnits: Record<string, string> = {
  "白陽八卦符": "組",
  "大國陰陽符": "組",
  "みろく鵺符": "組",
  "灶君護摩符": "組",
  "そう君護摩符": "組",
  "修霊超抜之御柱": "本"
};

const jsonError = (message: string, status = 400) => new Response(JSON.stringify({ error: message }), { status, headers: { "Content-Type": "application/json; charset=utf-8" } });
const now = () => new Date().toISOString();
const displayName = (fellowship: { code: string; name: string }) => `${fellowship.code} ${fellowship.name}`;
const normalize = (value: string) => value.replaceAll("　", " ").trim().toLocaleLowerCase();

function deadlineFromJapan(value: string) {
  if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(value)) return null;
  const deadline = new Date(`${value}:00+09:00`);
  return Number.isNaN(deadline.getTime()) ? null : deadline;
}

function japanDateOnly(value: Date) {
  const parts = new Intl.DateTimeFormat("en-US", { timeZone: "Asia/Tokyo", year: "numeric", month: "2-digit", day: "2-digit" }).formatToParts(value);
  const part = (type: string) => parts.find((entry) => entry.type === type)?.value ?? "";
  return `${part("year")}-${part("month")}-${part("day")}`;
}

function deadlineLabel(value: string | number) {
  return new Intl.DateTimeFormat("ja-JP", { timeZone: "Asia/Tokyo", year: "numeric", month: "long", day: "numeric", weekday: "short", hour: "2-digit", minute: "2-digit", hour12: false }).format(new Date(String(value)));
}

function japanMonthDay(value: string | number | null) {
  if (!value) return "";
  const date = new Date(String(value));
  if (Number.isNaN(date.getTime())) return "";
  return new Intl.DateTimeFormat("ja-JP", { timeZone: "Asia/Tokyo", month: "long", day: "numeric" }).format(date);
}

function toBase64Url(bytes: Uint8Array) {
  let value = "";
  bytes.forEach((byte) => { value += String.fromCharCode(byte); });
  return btoa(value).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

function toBase64(bytes: Uint8Array) {
  let value = "";
  bytes.forEach((byte) => { value += String.fromCharCode(byte); });
  return btoa(value);
}

function randomToken() {
  return toBase64Url(crypto.getRandomValues(new Uint8Array(32)));
}

function tokenProfile(token: string | undefined): Record<string, unknown> {
  const payload = token?.split(".")[1];
  if (!payload) return {};
  try {
    const normalized = payload.replaceAll("-", "+").replaceAll("_", "/");
    const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, "=");
    return JSON.parse(new TextDecoder().decode(Uint8Array.from(atob(padded), (character) => character.charCodeAt(0)))) as Record<string, unknown>;
  } catch {
    return {};
  }
}

async function sign(value: string, secret: string) {
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  return toBase64Url(new Uint8Array(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(value))));
}

async function signedValue(value: string, secret: string) {
  return `${value}.${await sign(value, secret)}`;
}

async function verifiedValue(value: string | undefined, secret: string) {
  if (!value) return null;
  const separator = value.lastIndexOf(".");
  if (separator < 1) return null;
  const data = value.slice(0, separator);
  const signature = value.slice(separator + 1);
  const expected = await sign(data, secret);
  return signature === expected ? data : null;
}

async function userFromSession(env: Env, sessionId?: string): Promise<SessionUser | null> {
  if (!sessionId) return null;
  const row = await env.DB.prepare(`SELECT u.id, u.name, u.email, u.role, u.fellowship_id AS fellowshipId,
      f.code AS fellowshipCode, f.name AS fellowshipName, s.csrf_token AS csrfToken
      FROM sessions s JOIN users u ON u.id = s.user_id JOIN fellowships f ON f.id = u.fellowship_id
      WHERE s.id = ? AND s.expires_at > ? AND u.active = 1`).bind(sessionId, now()).first<SessionUser>();
  return row ?? null;
}

app.use("*", async (c, next) => {
  const path = new URL(c.req.url).pathname;
  if (path === "/login" || path === "/auth/callback" || path === "/session/authentik/callback" || path === "/health") return next();
  const user = await userFromSession(c.env, getCookie(c, "bp_session"));
  if (!user) {
    if (path.startsWith("/api/")) return jsonError("ログインが必要です。", 401);
    return c.redirect("/login");
  }
  c.set("user", user);
  return next();
});

function user(c: { get(name: "user"): SessionUser }) {
  return c.get("user");
}

function requireAdmin(c: { get(name: "user"): SessionUser }) {
  if (user(c).role !== "admin") throw new Error("管理者のみ利用できます。");
}

function requireCsrf(c: { req: { header(name: string): string | undefined }; get(name: "user"): SessionUser }) {
  if (c.req.header("X-CSRF-Token") !== user(c).csrfToken) throw new Error("操作の確認に失敗しました。画面を再読み込みしてください。");
}

async function oidcConfiguration(env: Env) {
  const issuer = env.AUTHENTIK_ISSUER.endsWith("/") ? env.AUTHENTIK_ISSUER : `${env.AUTHENTIK_ISSUER}/`;
  const response = await fetch(`${issuer}.well-known/openid-configuration`);
  if (!response.ok) throw new Error("Authentikの接続情報を取得できませんでした。");
  return response.json<{ authorization_endpoint: string; token_endpoint: string; userinfo_endpoint: string }>();
}

function callbackUrl(request: Request) {
  const url = new URL(request.url);
  const forwardedHost = request.headers.get("X-Bulkpurchase-Host");
  const host = forwardedHost === "bulkpurchase.showway.biz" ? forwardedHost : url.hostname;
  // 既存のAuthentikプロバイダに登録済みのURLを、切替後もそのまま使う。
  url.protocol = "https:";
  url.hostname = host;
  url.pathname = host === "bulkpurchase.showway.biz" ? "/session/authentik/callback" : "/auth/callback";
  url.search = "";
  return url.toString();
}

app.get("/health", (c) => c.json({ ok: true }));

app.get("/login", async (c) => {
  try {
    const configuration = await oidcConfiguration(c.env);
    const state = randomToken();
    const nonce = randomToken();
    const cookie = await signedValue(JSON.stringify({ state, nonce }), c.env.SESSION_SECRET);
    setCookie(c, "bp_oauth", cookie, { httpOnly: true, secure: true, sameSite: "Lax", maxAge: 600, path: "/" });
    const callback = callbackUrl(c.req.raw);
    const authorization = new URL(configuration.authorization_endpoint);
    authorization.search = new URLSearchParams({
      client_id: c.env.AUTHENTIK_CLIENT_ID,
      redirect_uri: callback,
      response_type: "code",
      scope: "openid email profile groups",
      state,
      nonce
    }).toString();
    return c.redirect(authorization.toString());
  } catch (error) {
    return c.html(`<p>Authentikでログインできません。${error instanceof Error ? error.message : ""}</p>`, 500);
  }
});

const handleAuthentikCallback = async (c: Context<AppBindings>) => {
  try {
    const payload = await verifiedValue(getCookie(c, "bp_oauth"), c.env.SESSION_SECRET);
    deleteCookie(c, "bp_oauth", { path: "/" });
    const expected = payload ? JSON.parse(payload) as { state: string; nonce: string } : null;
    const state = c.req.query("state");
    const code = c.req.query("code");
    if (!expected || !state || state !== expected.state || !code) return c.html("ログイン情報の確認に失敗しました。", 400);
    const configuration = await oidcConfiguration(c.env);
    const callback = callbackUrl(c.req.raw);
    const tokenResponse = await fetch(configuration.token_endpoint, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({ grant_type: "authorization_code", code, redirect_uri: callback, client_id: c.env.AUTHENTIK_CLIENT_ID, client_secret: c.env.AUTHENTIK_CLIENT_SECRET })
    });
    if (!tokenResponse.ok) return c.html("Authentikの認証に失敗しました。", 401);
    const tokens = await tokenResponse.json<{ access_token: string; id_token?: string }>();
    const idTokenProfile = tokenProfile(tokens.id_token);
    if (idTokenProfile.nonce && idTokenProfile.nonce !== expected.nonce) return c.html("ログイン情報の確認に失敗しました。", 400);
    const profileResponse = await fetch(configuration.userinfo_endpoint, { headers: { Authorization: `Bearer ${tokens.access_token}` } });
    const userinfoProfile = profileResponse.ok ? await profileResponse.json<Record<string, unknown>>() : {};
    const profile = { ...tokenProfile(tokens.access_token), ...idTokenProfile, ...userinfoProfile };
    const groups = Array.isArray(profile.groups) ? profile.groups.map(String) : Array.isArray(profile.ak_groups) ? profile.ak_groups.map(String) : [];
    if (!groups.includes(c.env.AUTHENTIK_REQUIRED_GROUP || "myouou")) return c.html("ログインできるグループに所属していません。", 403);
    const fellowships = await c.env.DB.prepare(`SELECT id, code, name FROM fellowships WHERE active = 1 AND code IN (${managedCodes.map(() => "?").join(",")})`).bind(...managedCodes).all<Fellowship>();
    const fellowship = fellowships.results.find((entry) => {
      const candidates = [entry.code, entry.name, displayName(entry)].map(normalize);
      return groups.some((group) => candidates.includes(normalize(group)));
    });
    if (!fellowship) return c.html("Authentikに紐づく伝道会グループが見つかりません。", 403);
    const email = String(profile.email || profile.preferred_username || "").trim().toLowerCase();
    if (!email) return c.html("Authentikからメールアドレスを取得できませんでした。", 400);
    const name = String(profile.name || profile.preferred_username || email);
    const subject = String(profile.sub || email);
    const adminNames = (c.env.AUTHENTIK_ADMIN_USERNAMES || "myouou").split(",").map((entry) => entry.trim());
    const role = adminNames.includes(String(profile.preferred_username || "")) ? "admin" : "user";
    await c.env.DB.prepare(`INSERT INTO users (authentik_subject, email, name, fellowship_id, role, active, authentik_groups, updated_at)
      VALUES (?, ?, ?, ?, ?, 1, ?, ?)
      ON CONFLICT(authentik_subject) DO UPDATE SET email=excluded.email, name=excluded.name, fellowship_id=excluded.fellowship_id, role=excluded.role, active=1, authentik_groups=excluded.authentik_groups, updated_at=excluded.updated_at`)
      .bind(subject, email, name, fellowship.id, role, groups.join("\n"), now()).run();
    const savedUser = await c.env.DB.prepare("SELECT id FROM users WHERE authentik_subject = ?").bind(subject).first<{ id: number }>();
    if (!savedUser) throw new Error("ユーザーの保存に失敗しました。");
    const sessionId = randomToken();
    const csrfToken = randomToken();
    const expiresAt = new Date(Date.now() + 1000 * 60 * 60 * 24 * 30).toISOString();
    await c.env.DB.prepare("INSERT INTO sessions (id, user_id, csrf_token, expires_at) VALUES (?, ?, ?, ?)").bind(sessionId, savedUser.id, csrfToken, expiresAt).run();
    setCookie(c, "bp_session", sessionId, { httpOnly: true, secure: true, sameSite: "Lax", path: "/", maxAge: 60 * 60 * 24 * 30 });
    return c.redirect("/current-order");
  } catch (error) {
    return c.html(`Authentikログインに失敗しました。${error instanceof Error ? error.message : ""}`, 500);
  }
};

app.get("/auth/callback", handleAuthentikCallback);
app.get("/session/authentik/callback", handleAuthentikCallback);

app.get("/logout", async (c) => {
  const sessionId = getCookie(c, "bp_session");
  if (sessionId) await c.env.DB.prepare("DELETE FROM sessions WHERE id = ?").bind(sessionId).run();
  deleteCookie(c, "bp_session", { path: "/" });
  return c.redirect("/login");
});

app.get("/", (c) => c.redirect("/current-order"));
app.get("/current-order", (c) => c.html(renderPage(user(c), "current")));
app.get("/orders", (c) => c.html(renderPage(user(c), "history")));
app.get("/admin", (c) => user(c).role === "admin" ? c.html(renderPage(user(c), "admin")) : c.text("管理者のみ利用できます。", 403));

async function currentCycle(env: Env) {
  const nowValue = now();
  return env.DB.prepare("SELECT * FROM order_cycles WHERE status != 'sent' AND (deadline_at >= ? OR additional_order_until >= ?) ORDER BY CASE WHEN deadline_at >= ? THEN 0 ELSE 1 END, deadline_at ASC LIMIT 1").bind(nowValue, nowValue, nowValue).first<Record<string, string | number | null>>();
}

async function fellowships(env: Env) {
  const result = await env.DB.prepare(`SELECT id, code, name FROM fellowships WHERE active = 1 AND code IN (${managedCodes.map(() => "?").join(",")}) ORDER BY code`).bind(...managedCodes).all<Fellowship>();
  return result.results;
}

app.get("/api/items", async (c) => {
  const query = (c.req.query("q") || "").replace(/[０-９]/g, (character) => String.fromCharCode(character.charCodeAt(0) - 65248)).trim();
  if (query.length < 2) return c.json({ items: [] });
  const normalized = /^(灶君|竈君|そう君)/.test(query) ? "灶君護摩符" : query;
  const rows = await c.env.DB.prepare("SELECT id, code, name, unit, special_handling_type FROM items WHERE active = 1 AND (code LIKE ? OR name LIKE ?) ORDER BY code LIMIT 20").bind(`${normalized}%`, `${normalized}%`).all<Item>();
  return c.json({ items: rows.results });
});

app.get("/api/current-order", async (c) => {
  const loggedInUser = user(c);
  const cycle = await currentCycle(c.env);
  if (!cycle) return c.json({ cycle: null });
  const availableFellowships = await fellowships(c.env);
  const selectedId = loggedInUser.role === "admin" ? Number(c.req.query("fellowshipId") || loggedInUser.fellowshipId) : loggedInUser.fellowshipId;
  const fellowship = availableFellowships.find((entry) => entry.id === selectedId) ?? availableFellowships.find((entry) => entry.id === loggedInUser.fellowshipId);
  if (!fellowship) return jsonError("所属伝道会が見つかりません。", 403);
  const order = await c.env.DB.prepare("SELECT * FROM orders WHERE order_cycle_id = ? AND fellowship_id = ?").bind(cycle.id, fellowship.id).first<Record<string, string | number>>();
  const items = order ? (await c.env.DB.prepare("SELECT item_id AS itemId, item_code AS itemCode, item_name AS itemName, variant_name AS variantName, quantity, unit, sort_order AS sortOrder FROM order_items WHERE order_id = ? ORDER BY sort_order, id").bind(order.id).all()).results : [];
  const deadline = new Date(String(cycle.deadline_at));
  return c.json({
    admin: loggedInUser.role === "admin",
    fellowships: availableFellowships,
    cycle: { id: cycle.id, label: `${cycle.year}年${String(cycle.month).padStart(2, "0")}月`, orderDate: cycle.order_date, arrivalDate: cycle.arrival_date, deadlineDate: new Intl.DateTimeFormat("ja-JP", { timeZone: "Asia/Tokyo", year: "numeric", month: "long", day: "numeric", weekday: "short" }).format(deadline), deadlineTime: new Intl.DateTimeFormat("ja-JP", { timeZone: "Asia/Tokyo", hour: "2-digit", minute: "2-digit", hour12: false }).format(deadline), additionalOrderUntil: cycle.additional_order_until || null },
    order: { fellowshipId: fellowship.id, fellowshipLabel: displayName(fellowship), ordererName: order?.orderer_name || loggedInUser.name, pickupName: order?.pickup_name || "", status: order?.status || "draft", registered: Boolean(order), items }
  });
});

app.put("/api/current-order", async (c) => {
  try {
    requireCsrf(c);
    const loggedInUser = user(c);
    const body = await c.req.json<Record<string, unknown>>();
    const cycle = await currentCycle(c.env);
    if (!cycle) return jsonError("受付中の注文サイクルがありません。", 422);
    const availableFellowships = await fellowships(c.env);
    const requestedId = Number(body.fellowshipId || loggedInUser.fellowshipId);
    const fellowshipId = loggedInUser.role === "admin" ? requestedId : loggedInUser.fellowshipId;
    const fellowship = availableFellowships.find((entry) => entry.id === fellowshipId);
    if (!fellowship) return jsonError("伝道会を確認してください。", 422);
    const ordererName = String(body.ordererName || "").trim();
    const pickupName = String(body.pickupName || "").trim();
    const submitting = body.submit === true;
    const inputItems = Array.isArray(body.items) ? body.items : [];
    if (!ordererName || (!pickupName && !submitting)) return jsonError("注文者名と持ち帰り者名を入力してください。", 422);
    if (submitting && !pickupName) return jsonError("持ち帰り者名を入力してください。", 422);
    const normalizedItems = [] as Array<{ itemId: number | null; itemCode: string | null; itemName: string; variantName: string; quantity: number; unit: string; sortOrder: number }>;
    for (const [index, value] of inputItems.entries()) {
      if (!value || typeof value !== "object") continue;
      const entry = value as Record<string, unknown>;
      const itemName = String(entry.itemName || "").trim();
      const quantity = Number(entry.quantity);
      if (!itemName && !quantity) continue;
      const itemId = entry.itemId ? Number(entry.itemId) : null;
      const item = itemId ? await c.env.DB.prepare("SELECT id, code, name, unit, special_handling_type FROM items WHERE id = ? AND active = 1").bind(itemId).first<Item>() : null;
      const unit = fixedUnits[itemName] || item?.unit || String(entry.unit || "").trim();
      const variantName = String(entry.variantName || "").trim();
      const needsVariant = item?.code === "201002";
      const selectionVariants = item?.code === "210001" || /灶君|そう君/.test(itemName) || item?.code === "205002" || itemName.includes("四神獣符");
      if (!itemName || !Number.isInteger(quantity) || quantity <= 0 || !unit) return jsonError("道具名・数量・単位を正しく入力してください。", 422);
      if ((needsVariant || selectionVariants) && !variantName) return jsonError("種別を入力してください。", 422);
      normalizedItems.push({ itemId: item?.id || null, itemCode: item?.code || String(entry.itemCode || "") || null, itemName: item?.name || itemName, variantName, quantity, unit, sortOrder: index });
    }
    if (submitting && normalizedItems.length === 0) return jsonError("提出時は道具を1件以上入力してください。", 422);
    const existing = await c.env.DB.prepare("SELECT id, status FROM orders WHERE order_cycle_id = ? AND fellowship_id = ?").bind(cycle.id, fellowship.id).first<{ id: number; status: string }>();
    const orderId = existing?.id ?? (await c.env.DB.prepare("INSERT INTO orders (order_cycle_id, fellowship_id, user_id, orderer_name, pickup_name, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?, 'draft', ?, ?)").bind(cycle.id, fellowship.id, loggedInUser.id, ordererName, pickupName, now(), now()).run()).meta.last_row_id as number;
    const statements: D1PreparedStatement[] = [c.env.DB.prepare("UPDATE orders SET user_id = ?, orderer_name = ?, pickup_name = ?, status = ?, submitted_at = ?, updated_at = ? WHERE id = ?").bind(loggedInUser.id, ordererName, pickupName, submitting ? "submitted" : "draft", submitting ? now() : null, now(), orderId), c.env.DB.prepare("DELETE FROM order_items WHERE order_id = ?").bind(orderId)];
    normalizedItems.forEach((item) => statements.push(c.env.DB.prepare("INSERT INTO order_items (order_id, item_id, item_code, item_name, variant_name, quantity, unit, sort_order) VALUES (?, ?, ?, ?, ?, ?, ?, ?)").bind(orderId, item.itemId, item.itemCode, item.itemName, item.variantName || null, item.quantity, item.unit, item.sortOrder)));
    await c.env.DB.batch(statements);
    return c.json({ ok: true });
  } catch (error) {
    return jsonError(error instanceof Error ? error.message : "注文を保存できませんでした。", 422);
  }
});

app.get("/api/orders", async (c) => {
  const loggedInUser = user(c);
  const admin = loggedInUser.role === "admin";
  const query = admin ? "SELECT o.*, f.code, f.name AS fellowship_name, oc.year, oc.month FROM orders o JOIN fellowships f ON f.id=o.fellowship_id JOIN order_cycles oc ON oc.id=o.order_cycle_id ORDER BY oc.year DESC, oc.month DESC, f.code" : "SELECT o.*, f.code, f.name AS fellowship_name, oc.year, oc.month FROM orders o JOIN fellowships f ON f.id=o.fellowship_id JOIN order_cycles oc ON oc.id=o.order_cycle_id WHERE o.fellowship_id = ? ORDER BY oc.year DESC, oc.month DESC";
  const statement = c.env.DB.prepare(query);
  const itemQuery = admin ? "SELECT oi.order_id, oi.item_name, oi.variant_name, oi.quantity, oi.unit, oi.sort_order FROM order_items oi JOIN orders o ON o.id = oi.order_id ORDER BY oi.order_id, oi.sort_order, oi.id" : "SELECT oi.order_id, oi.item_name, oi.variant_name, oi.quantity, oi.unit, oi.sort_order FROM order_items oi JOIN orders o ON o.id = oi.order_id WHERE o.fellowship_id = ? ORDER BY oi.order_id, oi.sort_order, oi.id";
  const [rows, pastCycles, orderItems] = await Promise.all([
    admin ? statement.all<Record<string, string | number | null>>() : statement.bind(loggedInUser.fellowshipId).all<Record<string, string | number | null>>(),
    c.env.DB.prepare("SELECT year, month FROM order_cycles WHERE deadline_at < ? ORDER BY year DESC, month DESC").bind(now()).all<{ year: number; month: number }>(),
    admin ? c.env.DB.prepare(itemQuery).all<Record<string, string | number | null>>() : c.env.DB.prepare(itemQuery).bind(loggedInUser.fellowshipId).all<Record<string, string | number | null>>()
  ]);
  const label = (year: number, month: number) => `${year}年${String(month).padStart(2, "0")}月`;
  const months = new Map<string, { label: string; year: number; month: number }>();
  [...rows.results, ...pastCycles.results].forEach((entry) => months.set(label(Number(entry.year), Number(entry.month)), { label: label(Number(entry.year), Number(entry.month)), year: Number(entry.year), month: Number(entry.month) }));
  const itemsByOrder = new Map<number, Array<{ itemName: string; variantName: string; quantity: number; unit: string }>>();
  orderItems.results.forEach((entry) => {
    const orderId = Number(entry.order_id);
    const values = itemsByOrder.get(orderId) ?? [];
    values.push({ itemName: String(entry.item_name), variantName: String(entry.variant_name || ""), quantity: Number(entry.quantity), unit: String(entry.unit) });
    itemsByOrder.set(orderId, values);
  });
  return c.json({ months: [...months.values()].sort((a, b) => b.year - a.year || b.month - a.month).map((entry) => entry.label), orders: rows.results.map((entry) => ({ id: Number(entry.id), label: `${entry.year}年${String(entry.month).padStart(2, "0")}月`, fellowship: `${entry.code} ${entry.fellowship_name}`, ordererName: entry.orderer_name, status: entry.status === "submitted" ? "提出済み" : "下書き", submittedAt: japanMonthDay(entry.submitted_at), items: itemsByOrder.get(Number(entry.id)) ?? [] })) });
});

app.get("/api/admin/bootstrap", async (c) => {
  try {
    requireAdmin(c);
    const [cycles, orders, orderItems, items, users, fellowshipRows] = await Promise.all([
      c.env.DB.prepare("SELECT id, year, month, deadline_at, arrival_date, status, tendo_send_at, tendo_sent_at, tendo_send_error FROM order_cycles ORDER BY year DESC, month DESC").all<Record<string, string | number | null>>(),
      c.env.DB.prepare("SELECT o.id, o.orderer_name, o.status, f.code, f.name AS fellowship_name, oc.year, oc.month FROM orders o JOIN fellowships f ON f.id=o.fellowship_id JOIN order_cycles oc ON oc.id=o.order_cycle_id ORDER BY oc.year DESC, oc.month DESC, f.code").all<Record<string, string | number>>(),
      c.env.DB.prepare("SELECT order_id, item_name, variant_name, quantity, unit, sort_order FROM order_items ORDER BY order_id, sort_order, id").all<Record<string, string | number | null>>(),
      c.env.DB.prepare("SELECT id, code, name, unit FROM items ORDER BY code").all<Item>(),
      c.env.DB.prepare("SELECT u.name, u.email, u.role, f.code, f.name AS fellowship_name FROM users u JOIN fellowships f ON f.id=u.fellowship_id ORDER BY u.name").all<Record<string, string>>(),
      fellowships(c.env)
    ]);
    const itemsByOrder = new Map<number, Array<{ itemName: string; variantName: string; quantity: number; unit: string }>>();
    orderItems.results.forEach((entry) => {
      const orderId = Number(entry.order_id);
      const values = itemsByOrder.get(orderId) ?? [];
      values.push({ itemName: String(entry.item_name), variantName: String(entry.variant_name || ""), quantity: Number(entry.quantity), unit: String(entry.unit) });
      itemsByOrder.set(orderId, values);
    });
    return c.json({ cycles: cycles.results.map((entry) => ({ id: entry.id, label: `${entry.year}年${String(entry.month).padStart(2, "0")}月`, deadlineAt: entry.deadline_at, deadlineLabel: deadlineLabel(String(entry.deadline_at)), arrivalDate: entry.arrival_date, status: entry.status === "open" ? "受付中" : entry.status === "closed" ? "締切" : "送信済み", tendoSendAt: entry.tendo_send_at, tendoSendLabel: entry.tendo_send_at ? deadlineLabel(String(entry.tendo_send_at)) : "未設定", tendoSentAt: entry.tendo_sent_at, tendoSendError: entry.tendo_send_error })), orders: orders.results.map((entry) => ({ label: `${entry.year}年${String(entry.month).padStart(2, "0")}月`, fellowship: `${entry.code} ${entry.fellowship_name}`, ordererName: entry.orderer_name, status: entry.status === "submitted" ? "提出済み" : "下書き", items: itemsByOrder.get(Number(entry.id)) ?? [] })), items: items.results, users: users.results.map((entry) => ({ name: entry.name, email: entry.email, role: entry.role === "admin" ? "管理者" : "利用者", fellowship: `${entry.code} ${entry.fellowship_name}` })), fellowships: fellowshipRows });
  } catch (error) {
    return jsonError(error instanceof Error ? error.message : "管理情報を取得できませんでした。", 403);
  }
});

app.post("/api/admin/cycles", async (c) => {
  try {
    requireAdmin(c); requireCsrf(c);
    const body = await c.req.json<Record<string, string>>();
    const [year, month] = String(body.month || "").split("-").map(Number);
    const deadline = deadlineFromJapan(body.deadlineAt);
    const tendoSendAt = body.tendoSendAt ? deadlineFromJapan(body.tendoSendAt) : deadline;
    const arrivalDate = body.arrivalDate;
    if (!year || !month || !deadline || !tendoSendAt || !/^\d{4}-\d{2}-\d{2}$/.test(arrivalDate)) return jsonError("対象月・締切日時・必着日・自動送信日時を入力してください。", 422);
    await c.env.DB.prepare("INSERT INTO order_cycles (year, month, deadline_at, order_date, arrival_date, status, tendo_send_at, created_at, updated_at) VALUES (?, ?, ?, ?, ?, 'open', ?, ?, ?)").bind(year, month, deadline.toISOString(), japanDateOnly(new Date(deadline.getTime() + 86400000)), arrivalDate, tendoSendAt.toISOString(), now(), now()).run();
    return c.json({ ok: true });
  } catch (error) { return jsonError(error instanceof Error ? error.message : "注文サイクルを登録できませんでした。", 422); }
});

app.put("/api/admin/cycles/:id", async (c) => {
  try {
    requireAdmin(c); requireCsrf(c);
    const body = await c.req.json<Record<string, string>>();
    const [year, month] = String(body.month || "").split("-").map(Number);
    const deadline = deadlineFromJapan(body.deadlineAt);
    const tendoSendAt = body.tendoSendAt ? deadlineFromJapan(body.tendoSendAt) : null;
    const arrivalDate = body.arrivalDate;
    const cycleId = Number(c.req.param("id"));
    if (!cycleId || !year || !month || !deadline || (body.tendoSendAt && !tendoSendAt) || !/^\d{4}-\d{2}-\d{2}$/.test(arrivalDate)) return jsonError("対象月・締切日時・必着日・自動送信日時を入力してください。", 422);
    const duplicate = await c.env.DB.prepare("SELECT id FROM order_cycles WHERE year = ? AND month = ? AND id != ?").bind(year, month, cycleId).first();
    if (duplicate) return jsonError("同じ対象月の注文サイクルが既に登録されています。", 422);
    const result = await c.env.DB.prepare("UPDATE order_cycles SET year=?, month=?, deadline_at=?, order_date=?, arrival_date=?, tendo_send_at=COALESCE(?, tendo_send_at, ?), updated_at=? WHERE id=?")
      .bind(year, month, deadline.toISOString(), japanDateOnly(new Date(deadline.getTime() + 86400000)), arrivalDate, tendoSendAt?.toISOString() ?? null, deadline.toISOString(), now(), cycleId).run();
    if (!result.meta.changes) return jsonError("注文サイクルが見つかりません。", 404);
    return c.json({ ok: true });
  } catch (error) { return jsonError(error instanceof Error ? error.message : "注文サイクルを更新できませんでした。", 422); }
});

async function pdfData(env: Env, cycleId: number) {
  const cycle = await env.DB.prepare("SELECT * FROM order_cycles WHERE id = ?").bind(cycleId).first<Record<string, string | number>>();
  if (!cycle) throw new Error("注文サイクルが見つかりません。");
  const fellowshipsForPdf = (await env.DB.prepare("SELECT DISTINCT f.id, f.name, f.code FROM orders o JOIN fellowships f ON f.id=o.fellowship_id WHERE o.order_cycle_id=? AND o.status='submitted' ORDER BY f.code").bind(cycleId).all<{ id: number; name: string; code: string }>()).results;
  const lines = (await env.DB.prepare("SELECT oi.item_code, oi.item_name, oi.variant_name, oi.unit, oi.quantity, o.fellowship_id FROM order_items oi JOIN orders o ON o.id=oi.order_id WHERE o.order_cycle_id=? AND o.status='submitted' ORDER BY oi.item_code, oi.item_name").bind(cycleId).all<Record<string, string | number | null>>()).results;
  const grouped = new Map<string, { name: string; unit: string; quantities: Record<number, number>; total: number }>();
  lines.forEach((line) => { const itemName = String(line.item_name); const variant = line.variant_name ? itemName === "白陽八卦符" ? `「${line.variant_name}」` : `(${line.variant_name})` : ""; const name = `${itemName}${variant}`; const key = `${line.item_code}|${name}|${line.unit}`; const row = grouped.get(key) ?? { name, unit: String(line.unit), quantities: {}, total: 0 }; const fellowshipId = Number(line.fellowship_id); const quantity = Number(line.quantity); row.quantities[fellowshipId] = (row.quantities[fellowshipId] || 0) + quantity; row.total += quantity; grouped.set(key, row); });
  return { cycle, fellowships: fellowshipsForPdf, rows: [...grouped.values()] };
}

app.get("/api/admin/cycles/:id/pdf", async (c) => {
  try {
    requireAdmin(c);
    const data = await pdfData(c.env, Number(c.req.param("id")));
    const bytes = await createOrderPdf({ label: `${data.cycle.year}年${String(data.cycle.month).padStart(2, "0")}月`, orderDate: String(data.cycle.order_date), arrivalDate: String(data.cycle.arrival_date), fellowships: data.fellowships, rows: data.rows }, c.env.BROWSER);
    const filename = `${data.cycle.year}年${String(data.cycle.month).padStart(2, "0")}月_一括道具注文書.pdf`;
    return new Response(new Uint8Array(bytes).buffer, { headers: { "Content-Type": "application/pdf", "Content-Disposition": `attachment; filename="bulk-order.pdf"; filename*=UTF-8''${encodeURIComponent(filename)}` } });
  } catch (error) { return c.text(error instanceof Error ? error.message : "PDFを出力できませんでした。", 422); }
});

app.post("/api/admin/cycles/:id/email", async (c) => {
  try {
    requireAdmin(c); requireCsrf(c);
    await sendNotificationEmail(c.env, Number(c.req.param("id")));
    return c.json({ ok: true });
  } catch (error) { return jsonError(error instanceof Error ? error.message : "通知メールを送信できませんでした。", 422); }
});

async function recordTendoSend(env: Env, cycleId: number, channel: "tendo" | "email", automatic: boolean, status: "success" | "failed", detail: string) {
  await env.DB.prepare("INSERT INTO tendo_send_logs (order_cycle_id, channel, trigger_type, status, detail, sent_at) VALUES (?, ?, ?, ?, ?, ?)")
    .bind(cycleId, channel, automatic ? "automatic" : "manual", status, detail.slice(0, 500), now()).run();
}

async function sendNotificationEmail(env: Env, cycleId: number, automatic = false) {
  if (!env.RESEND_API_KEY || !env.RESEND_FROM) throw new Error("通知メールの送信設定がまだ完了していません。");
  const data = await pdfData(env, cycleId);
  const label = `${data.cycle.year}年${String(data.cycle.month).padStart(2, "0")}月`;
  const bytes = await createOrderPdf({ label, orderDate: String(data.cycle.order_date), arrivalDate: String(data.cycle.arrival_date), fellowships: data.fellowships, rows: data.rows }, env.BROWSER);
  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { Authorization: `Bearer ${env.RESEND_API_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify({ from: env.RESEND_FROM, to: [env.TENDO_NOTIFICATION_EMAIL], subject: `【一括注文】${label}分`, html: `<p>${label}の道具一括注文書を添付します。</p>`, attachments: [{ filename: "一括道具注文書.pdf", content: toBase64(new Uint8Array(bytes)) }] })
  });
  if (!response.ok) {
    const message = `通知メールの送信に失敗しました（HTTP ${response.status}）`;
    await recordTendoSend(env, cycleId, "email", automatic, "failed", message);
    throw new Error(message);
  }
  const sentColumn = automatic ? "tendo_auto_email_sent_at" : "tendo_email_sent_at";
  await env.DB.prepare(`UPDATE order_cycles SET ${sentColumn}=?, tendo_send_error=NULL, updated_at=? WHERE id=?`).bind(now(), now(), cycleId).run();
  await recordTendoSend(env, cycleId, "email", automatic, "success", `HTTP ${response.status} / ${env.TENDO_NOTIFICATION_EMAIL}へ送信`);
}

async function sendTendoPdf(env: Env, cycleId: number, automatic = true) {
  const data = await pdfData(env, cycleId);
  const bytes = await createOrderPdf({ label: `${data.cycle.year}年${String(data.cycle.month).padStart(2, "0")}月`, orderDate: String(data.cycle.order_date), arrivalDate: String(data.cycle.arrival_date), fellowships: data.fellowships, rows: data.rows }, env.BROWSER);
  const form = new FormData();
  form.set("name", env.TENDO_SENDER_NAME); form.set("dendokai", env.TENDO_FELLOWSHIP_NAME); form.set("title", `${data.cycle.year}年${String(data.cycle.month).padStart(2, "0")}月 道具一括注文書`); form.set("text", "道具一括注文書を送信します。"); form.set(env.TENDO_DESTINATION || "mirokuji", "送信");
  form.set("up_file[]", new File([new Uint8Array(bytes).buffer], "一括道具注文書.pdf", { type: "application/pdf" }));
  const response = await fetch(env.TENDO_UPLOAD_URL, { method: "POST", body: form });
  if (!response.ok) {
    const message = `天道へのPDF送信に失敗しました（HTTP ${response.status}）`;
    await recordTendoSend(env, cycleId, "tendo", automatic, "failed", message);
    throw new Error(message);
  }
  await env.DB.prepare("UPDATE order_cycles SET tendo_sent_at=?, tendo_send_error=NULL, updated_at=? WHERE id=?").bind(now(), now(), cycleId).run();
  await recordTendoSend(env, cycleId, "tendo", automatic, "success", `HTTP ${response.status} / 天道へPDF送信`);
}

app.get("/api/admin/tendo-status", async (c) => {
  try {
    requireAdmin(c);
    const [cycles, logs] = await Promise.all([
      c.env.DB.prepare("SELECT id, year, month, tendo_send_at, tendo_sent_at, tendo_email_sent_at, tendo_auto_email_sent_at, tendo_send_error, additional_order_until FROM order_cycles ORDER BY year DESC, month DESC").all<Record<string, string | number | null>>(),
      c.env.DB.prepare("SELECT l.order_cycle_id, l.channel, l.trigger_type, l.status, l.detail, l.sent_at, c.year, c.month FROM tendo_send_logs l JOIN order_cycles c ON c.id=l.order_cycle_id ORDER BY l.sent_at DESC LIMIT 50").all<Record<string, string | number>>()
    ]);
    return c.json({
      notificationEmail: c.env.TENDO_NOTIFICATION_EMAIL,
      senderName: c.env.TENDO_SENDER_NAME,
      fellowshipName: c.env.TENDO_FELLOWSHIP_NAME,
      cycles: cycles.results.map((cycle) => ({ id: cycle.id, label: `${cycle.year}年${String(cycle.month).padStart(2, "0")}月`, tendoSendAt: cycle.tendo_send_at, tendoSentAt: cycle.tendo_sent_at, emailSentAt: cycle.tendo_auto_email_sent_at, manualEmailSentAt: cycle.tendo_email_sent_at, error: cycle.tendo_send_error, additionalOrderUntil: cycle.additional_order_until })),
      logs: logs.results.map((log) => ({ cycleId: log.order_cycle_id, label: `${log.year}年${String(log.month).padStart(2, "0")}月`, channel: log.channel, triggerType: log.trigger_type, status: log.status, detail: log.detail, sentAt: log.sent_at }))
    });
  } catch (error) { return jsonError(error instanceof Error ? error.message : "送信状況を取得できませんでした。", 403); }
});

app.post("/api/admin/cycles/:id/tendo", async (c) => {
  try {
    requireAdmin(c); requireCsrf(c);
    const cycleId = Number(c.req.param("id"));
    if (!cycleId) return jsonError("注文サイクルが見つかりません。", 404);
    await sendTendoPdf(c.env, cycleId, false);
    await sendNotificationEmail(c.env, cycleId, false);
    return c.json({ ok: true });
  } catch (error) { return jsonError(error instanceof Error ? error.message : "天道への再送信に失敗しました。", 422); }
});

app.post("/api/admin/cycles/:id/additional-order", async (c) => {
  try {
    requireAdmin(c); requireCsrf(c);
    const cycleId = Number(c.req.param("id"));
    if (!cycleId) return jsonError("注文サイクルが見つかりません。", 404);
    const additionalOrderUntil = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
    const result = await c.env.DB.prepare("UPDATE order_cycles SET additional_order_until=?, updated_at=? WHERE id=?").bind(additionalOrderUntil, now(), cycleId).run();
    if (!result.meta.changes) return jsonError("注文サイクルが見つかりません。", 404);
    return c.json({ ok: true, additionalOrderUntil });
  } catch (error) { return jsonError(error instanceof Error ? error.message : "追加注文の受付を開始できませんでした。", 422); }
});

async function scheduledSend(env: Env) {
  const emailEnabled = Boolean(env.RESEND_API_KEY && env.RESEND_FROM);
  const cycles = await env.DB.prepare("SELECT id, tendo_sent_at, tendo_auto_email_sent_at FROM order_cycles WHERE tendo_send_at IS NOT NULL AND tendo_send_at <= ? AND (tendo_sent_at IS NULL OR (? = 1 AND tendo_auto_email_sent_at IS NULL))").bind(now(), emailEnabled ? 1 : 0).all<{ id: number; tendo_sent_at: string | null; tendo_auto_email_sent_at: string | null }>();
  for (const cycle of cycles.results) {
    try {
      if (!cycle.tendo_sent_at) await sendTendoPdf(env, cycle.id, true);
      if (emailEnabled && !cycle.tendo_auto_email_sent_at) await sendNotificationEmail(env, cycle.id, true);
    } catch (error) { await env.DB.prepare("UPDATE order_cycles SET tendo_send_error=?, updated_at=? WHERE id=?").bind(error instanceof Error ? error.message.slice(0, 500) : "PDF送信に失敗しました。", now(), cycle.id).run(); }
  }
  await env.DB.prepare("DELETE FROM sessions WHERE expires_at <= ?").bind(now()).run();
}

export default {
  fetch: app.fetch,
  scheduled: (_event: ScheduledEvent, env: Env, ctx: ExecutionContext) => ctx.waitUntil(scheduledSend(env))
};
