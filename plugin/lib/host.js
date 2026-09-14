/**
 * dsh-pet — host half.
 *
 * Exposes a tiny read-only HTTP surface for the "balance pet" client widget:
 *
 *   GET  /pet-api/state        current balance + today's estimated usage
 *   GET  /pet-api/asset/pet.png the character sticker
 *   POST /pet-api/event        widget telemetry (mount, pet, stroke, refresh)
 *   POST /pet-api/refresh      force a balance refresh
 *   GET  /pet-api/enabled      whether the widget should render at all
 *   POST /pet-api/enabled      turn the widget on/off ({"enabled": bool})
 *
 * The DeepSeek balance comes from the official account endpoint; the API key is
 * resolved the same way the LLM adapters resolve `apiKeyEnv: DEEPSEEK_API_KEY`
 * (process environment first, then the managed credential document).
 *
 * Today's usage is estimated from balance drops observed while this plugin is
 * running: top-ups (balance increases) never count as usage.
 */
import { appendFileSync, existsSync, mkdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const name = "dsh-pet";
/** The web carrier provides the HTTP surface this plugin registers on. */
const inject = ["webServer"];

const HOME = process.env.DSH_HOME && process.env.DSH_HOME.trim() !== ""
  ? process.env.DSH_HOME.trim()
  : join(homedir(), ".dsh");
/**
 * This plugin's own folder, resolved from this module rather than assumed to sit
 * at $DSH_HOME/plugins/dsh-pet, so the plugin works from any install location.
 */
const PLUGIN_DIR = join(dirname(fileURLToPath(import.meta.url)), "..");
const DATA_DIR = join(PLUGIN_DIR, "data");
const ASSET_DIR = join(PLUGIN_DIR, "assets");
const ASSET_PATH = join(ASSET_DIR, "pet.png");
const USAGE_PATH = join(DATA_DIR, "usage.json");
const EVENT_LOG = join(DATA_DIR, "widget.log");
const BALANCE_BASE = (process.env.DEEPSEEK_BASE_URL ?? "https://api.deepseek.com").replace(/\/+$/u, "");
const BALANCE_URL = `${BALANCE_BASE}/user/balance`;
const API_KEY_NAME = "DEEPSEEK_API_KEY";
/** Balance is refetched at most this often; the widget polls slower than this. */
const CACHE_MS = 45_000;

/** @type {{ payload: object | null, fetchedAt: number, error: string | null, inflight: Promise<void> | null }} */
const cache = { payload: null, fetchedAt: 0, error: null, inflight: null };
/** Host context captured on apply, so route handlers can read sibling services. */
let ctxRef = null;

function ensureDir(dir) {
  try {
    mkdirSync(dir, { recursive: true });
  } catch {
    /* a read-only home still leaves the widget working without persistence */
  }
}

function logEvent(entry) {
  try {
    ensureDir(DATA_DIR);
    appendFileSync(EVENT_LOG, `${JSON.stringify({ at: new Date().toISOString(), ...entry })}\n`);
  } catch {
    /* telemetry is best effort */
  }
}

function readYamlRefs(text) {
  const refs = {};
  let inRefs = false;
  for (const raw of text.split(/\r?\n/u)) {
    const line = raw.replace(/\s+$/u, "");
    if (/^refs:\s*$/u.test(line)) {
      inRefs = true;
      continue;
    }
    if (inRefs) {
      if (/^\S/u.test(line)) break;
      const match = /^\s+([A-Za-z0-9_]+):\s*(.*)$/u.exec(line);
      if (match !== null) refs[match[1]] = match[2].replace(/^["']|["']$/gu, "");
    }
  }
  return refs;
}

function readDotEnv(path) {
  const out = {};
  try {
    if (!existsSync(path)) return out;
    for (const raw of readFileSync(path, "utf8").split(/\r?\n/u)) {
      const line = raw.trim();
      if (line === "" || line.startsWith("#")) continue;
      const eq = line.indexOf("=");
      if (eq <= 0) continue;
      const key = line.slice(0, eq).trim().replace(/^export\s+/u, "");
      out[key] = line.slice(eq + 1).trim().replace(/^["']|["']$/gu, "");
    }
  } catch {
    /* ignore */
  }
  return out;
}

/** Resolve the DeepSeek API key: environment, managed credentials, then .env files. */
function resolveApiKey() {
  const fromEnv = process.env[API_KEY_NAME];
  if (typeof fromEnv === "string" && fromEnv.trim() !== "") return fromEnv.trim();
  try {
    const managed = join(HOME, ".credentials.yaml");
    if (existsSync(managed)) {
      const refs = readYamlRefs(readFileSync(managed, "utf8"));
      if (refs[API_KEY_NAME]) return refs[API_KEY_NAME];
    }
  } catch {
    /* fall through to .env */
  }
  for (const candidate of [join(process.cwd(), ".env"), join(HOME, ".env")]) {
    const values = readDotEnv(candidate);
    if (values[API_KEY_NAME]) return values[API_KEY_NAME];
  }
  return null;
}

function round2(value) {
  return Math.round(value * 100) / 100;
}

function localDate(date = new Date()) {
  const pad = (n) => String(n).padStart(2, "0");
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

function emptyUsage() {
  return {
    date: localDate(),
    dayStartBalance: null,
    lastBalance: null,
    usedToday: 0,
    petsTotal: 0,
    petsToday: 0,
    lastTopUpAt: null,
    lastPetAt: null,
    lastStrokeAt: null
  };
}

function loadUsage() {
  try {
    if (!existsSync(USAGE_PATH)) return emptyUsage();
    const parsed = JSON.parse(readFileSync(USAGE_PATH, "utf8"));
    if (parsed === null || typeof parsed !== "object") return emptyUsage();
    return { ...emptyUsage(), ...parsed };
  } catch {
    return emptyUsage();
  }
}

function saveUsage(usage) {
  try {
    ensureDir(DATA_DIR);
    writeFileSync(USAGE_PATH, `${JSON.stringify(usage, null, 2)}\n`, "utf8");
  } catch {
    /* ignore */
  }
}

/** Fold one balance reading into the persisted day-scoped usage estimate. */
function recordBalance(total) {
  const usage = loadUsage();
  const today = localDate();
  if (usage.date !== today) {
    usage.date = today;
    usage.usedToday = 0;
    usage.petsToday = 0;
    usage.dayStartBalance = usage.lastBalance;
  }
  if (usage.dayStartBalance === null) usage.dayStartBalance = total;
  if (typeof usage.lastBalance === "number" && Number.isFinite(usage.lastBalance)) {
    const delta = round2(usage.lastBalance - total);
    if (delta > 0) usage.usedToday = round2(usage.usedToday + delta);
    else if (delta < 0) usage.lastTopUpAt = new Date().toISOString();
  }
  usage.lastBalance = total;
  saveUsage(usage);
  return usage;
}

async function fetchBalance() {
  const apiKey = resolveApiKey();
  if (apiKey === null) {
    return { ok: false, error: `no ${API_KEY_NAME} credential found (set the env var or use the Models page)` };
  }
  try {
    const response = await fetch(BALANCE_URL, {
      headers: { authorization: `Bearer ${apiKey}`, accept: "application/json" }
    });
    if (!response.ok) return { ok: false, error: `balance endpoint answered HTTP ${response.status}` };
    const body = await response.json();
    const info = Array.isArray(body?.balance_infos) ? body.balance_infos[0] : null;
    if (info === null || info === undefined) return { ok: false, error: "balance response carried no balance_infos" };
    const total = Number(info.total_balance);
    if (!Number.isFinite(total)) return { ok: false, error: "balance response carried no numeric total_balance" };
    return {
      ok: true,
      error: null,
      available: body.is_available === true,
      currency: typeof info.currency === "string" ? info.currency : "CNY",
      total: round2(total),
      granted: round2(Number(info.granted_balance ?? 0)),
      toppedUp: round2(Number(info.topped_up_balance ?? 0))
    };
  } catch (error) {
    return { ok: false, error: `balance request failed: ${error instanceof Error ? error.message : String(error)}` };
  }
}

async function refreshBalance(force) {
  const now = Date.now();
  if (!force && cache.payload !== null && now - cache.fetchedAt < CACHE_MS) return;
  if (cache.inflight !== null) return cache.inflight;
  cache.inflight = (async () => {
    const result = await fetchBalance();
    cache.fetchedAt = Date.now();
    if (result.ok) {
      cache.payload = result;
      cache.error = null;
      recordBalance(result.total);
    } else {
      cache.error = result.error;
    }
  })();
  try {
    await cache.inflight;
  } finally {
    cache.inflight = null;
  }
}

async function statePayload() {
  await refreshBalance(false);
  const usage = loadUsage();
  return {
    ok: cache.payload !== null && cache.error === null,
    error: cache.error,
    balance: cache.payload === null ? null : {
      currency: cache.payload.currency,
      total: cache.payload.total,
      granted: cache.payload.granted,
      toppedUp: cache.payload.toppedUp,
      available: cache.payload.available
    },
    usage: {
      date: usage.date,
      usedToday: usage.usedToday,
      dayStartBalance: usage.dayStartBalance,
      lastTopUpAt: usage.lastTopUpAt
    },
    pets: { total: usage.petsTotal, today: usage.petsToday, lastPetAt: usage.lastPetAt },
    enabled: readEnabled(),
    fetchedAt: cache.fetchedAt === 0 ? null : new Date(cache.fetchedAt).toISOString(),
    serverTime: new Date().toISOString()
  };
}

const ENABLED_PATH = join(DATA_DIR, "enabled.json");

/**
 * Whether the widget should exist at all. "关闭" (off) renders nothing — not even
 * the collapsed pill — so it is deliberately separate from the collapse state.
 * Missing or unreadable file means "on".
 */
function readEnabled() {
  try {
    const parsed = JSON.parse(readFileSync(ENABLED_PATH, "utf8"));
    if (parsed !== null && typeof parsed === "object" && typeof parsed.enabled === "boolean") {
      return parsed.enabled;
    }
  } catch {
    /* first run, or a read-only home */
  }
  return true;
}

function writeEnabled(enabled) {
  try {
    ensureDir(DATA_DIR);
    writeFileSync(ENABLED_PATH, JSON.stringify({ enabled: Boolean(enabled), at: new Date().toISOString() }, null, 2) + "\n");
  } catch {
    /* read-only home: the in-memory answer still flips for this request */
  }
}

function sendJson(res, status, body) {
  const text = JSON.stringify(body);
  res.writeHead(status, {
    "content-type": "application/json; charset=utf-8",
    "cache-control": "no-store"
  });
  res.end(text);
}

function sendAsset(res, method, name) {
  if (typeof name !== "string" || name === "" || name.includes("..") || name.includes("/") || name.includes("\\") || !/^[A-Za-z0-9._-]+\.png$/u.test(name)) {
    res.writeHead(400, { "content-type": "text/plain; charset=utf-8" });
    res.end("bad asset name");
    return;
  }
  const file = join(ASSET_DIR, name);
  try {
    const stat = statSync(file);
    res.writeHead(200, {
      "content-type": "image/png",
      "content-length": String(stat.size),
      "cache-control": "no-cache"
    });
    res.end(method === "HEAD" ? undefined : readFileSync(file));
  } catch {
    res.writeHead(404, { "content-type": "text/plain; charset=utf-8" });
    res.end("pet asset missing");
  }
}

function readBody(req) {
  return new Promise((resolve) => {
    let data = "";
    req.on("data", (chunk) => {
      data += chunk;
      if (data.length > 64_000) data = data.slice(0, 64_000);
    });
    req.on("end", () => resolve(data));
    req.on("error", () => resolve(""));
  });
}

function bumpPetCounter(kind) {
  const usage = loadUsage();
  const today = localDate();
  if (usage.date !== today) {
    usage.date = today;
    usage.usedToday = 0;
    usage.petsToday = 0;
  }
  const at = new Date().toISOString();
  if (kind === "stroke") {
    usage.lastStrokeAt = at;
  } else {
    usage.petsTotal = (usage.petsTotal ?? 0) + 1;
    usage.petsToday = (usage.petsToday ?? 0) + 1;
    usage.lastPetAt = at;
  }
  saveUsage(usage);
  return usage;
}

async function handler(req, res) {
  const method = (req.method ?? "GET").toUpperCase();
  const url = new URL(req.url ?? "/", "http://dsh.invalid");
  const path = url.pathname;

  if (method !== "GET" && method !== "HEAD" && method !== "POST") {
    sendJson(res, 405, { ok: false, error: "method not allowed" });
    return;
  }

  if (path === "/pet-api/state") {
    sendJson(res, 200, await statePayload());
    return;
  }

  // Lightweight switch endpoint: the widget polls this to know whether to exist.
  if (path === "/pet-api/enabled") {
    if (method === "POST") {
      const raw = await readBody(req);
      let desired = null;
      try {
        const parsed = raw === "" ? null : JSON.parse(raw);
        if (parsed !== null && typeof parsed === "object" && typeof parsed.enabled === "boolean") desired = parsed.enabled;
      } catch {
        desired = null;
      }
      if (desired === null) {
        sendJson(res, 400, { ok: false, error: "expected {enabled: boolean}" });
        return;
      }
      writeEnabled(desired);
      logEvent({ type: "enabled", detail: desired ? "on" : "off" });
    }
    sendJson(res, 200, { ok: true, enabled: readEnabled() });
    return;
  }

  if (path.startsWith("/pet-api/asset/")) {
    sendAsset(res, method, path.slice("/pet-api/asset/".length));
    return;
  }

  if (path === "/pet-api/refresh" && method === "POST") {
    await refreshBalance(true);
    sendJson(res, 200, await statePayload());
    return;
  }

  if (path === "/pet-api/event" && method === "POST") {
    const raw = await readBody(req);
    let parsed = null;
    try {
      parsed = raw === "" ? null : JSON.parse(raw);
    } catch {
      parsed = { type: "unparsed" };
    }
    const kind = parsed !== null && typeof parsed === "object" && typeof parsed.type === "string" ? parsed.type : "unknown";
    const usage = kind === "pet" || kind === "stroke" ? bumpPetCounter(kind) : null;
    logEvent({
      type: kind,
      detail: parsed !== null && typeof parsed === "object" ? parsed.detail ?? null : null,
      mood: parsed !== null && typeof parsed === "object" ? parsed.mood ?? null : null,
      petsTotal: usage === null ? undefined : usage.petsTotal
    });
    sendJson(res, 200, {
      ok: true,
      petsTotal: usage === null ? loadUsage().petsTotal : usage.petsTotal
    });
    return;
  }

  if (path === "/pet-api/diag") {
    const graph = ctxRef?.get?.("clientModules")?.graph?.();
    const entries = Array.isArray(graph?.entries) ? graph.entries : [];
    const mine = entries.find((entry) => entry.id === "dsh-pet") ?? null;
    sendJson(res, 200, {
      ok: true,
      home: HOME,
      asset: ASSET_PATH,
      assetExists: existsSync(ASSET_PATH),
      credentialSource: process.env[API_KEY_NAME] ? "environment" : "managed-or-env-file",
      hasApiKey: resolveApiKey() !== null,
      balanceEndpoint: BALANCE_URL,
      cacheAgeMs: cache.fetchedAt === 0 ? null : Date.now() - cache.fetchedAt,
      clientEntryPresent: mine !== null,
      clientEntry: mine,
      clientEntries: entries.map((entry) => entry.id)
    });
    return;
  }

  sendJson(res, 404, { ok: false, error: "not found" });
}

/**
 * Plugin body: register the read-only balance surface on the web carrier.
 * @param ctx - host plugin context.
 */
function apply(ctx) {
  ctxRef = ctx;
  ensureDir(DATA_DIR);
  ctx.effect(
    () => ctx.webServer.register({ kind: "prefix", path: "/pet-api", handler }),
    "dsh-pet: balance routes"
  );
  ctx.logger?.info?.("dsh-pet: balance pet routes mounted at /pet-api");
  logEvent({ type: "host-mounted" });
}

export { apply, inject, name };
