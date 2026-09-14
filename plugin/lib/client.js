/**
 * dsh-pet — client half.
 *
 * A floating "balance pet" for the DeepSeek Harness shell. The character is a
 * three-layer cutout (tail / ahoge / body) so the tail can wag and the hair loop
 * can wiggle independently, next to a speech bubble that reports the DeepSeek
 * account balance and today's estimated usage.
 *
 * Data comes from this plugin's own host half (`/pet-api/*`). Everything is
 * hand-written in the lazy-CJS factory form the browser module system expects,
 * and uses only `require("react")` plus DOM APIs.
 */
window.__ModuleLoader__.load({
	id: "dsh-pet",
	factory: (require) => {
		var module = { exports: {} };
		var exports = module.exports;
		Object.defineProperty(exports, Symbol.toStringTag, { value: "Module" });

		const react = require("react");
		const h = react.createElement;

		//#region styles
		const css = `
.dshpet-root{position:fixed;z-index:60;display:flex;align-items:flex-end;gap:8px;font-family:system-ui,-apple-system,"Segoe UI","PingFang SC","Microsoft YaHei",sans-serif;color:#1d2b52;user-select:none;-webkit-user-select:none;pointer-events:none}
.dshpet-bubble,.dshpet-sprite,.dshpet-pill,.dshpet-help{pointer-events:auto}
.dshpet-root[data-dragging="true"]{cursor:grabbing}
.dshpet-bubble{position:relative;box-sizing:border-box;width:236px;background:#fff;border:4px solid #1f3a8f;border-radius:26px;padding:11px 13px 10px;box-shadow:0 10px 26px rgba(16,32,84,.22)}
.dshpet-bubble::after{content:"";position:absolute;right:-14px;bottom:26px;width:24px;height:24px;background:#fff;border-right:4px solid #1f3a8f;border-bottom:4px solid #1f3a8f;transform:rotate(-45deg);border-radius:0 0 6px 0}
.dshpet-bubble.dshpet-pop{animation:dshpet-pop .31s cubic-bezier(.34,1.56,.64,1)}
@keyframes dshpet-pop{0%{transform:scale(.9)}60%{transform:scale(1.035)}100%{transform:scale(1)}}
.dshpet-title{font-size:12px;letter-spacing:.4px;color:#4a5f9c;font-weight:600}
.dshpet-amount{font-size:29px;line-height:1.14;font-weight:800;letter-spacing:.4px;font-variant-numeric:tabular-nums;color:#1f3a8f}
.dshpet-used{margin-top:2px;font-size:12.5px;color:#54679e;font-variant-numeric:tabular-nums}
.dshpet-used b{font-weight:700;color:#3a4e8c}
.dshpet-say{margin-top:7px;font-size:12.5px;line-height:1.5;color:#26365f;min-height:34px}
.dshpet-meta{margin-top:6px;font-size:11px;color:#8b97b8;display:flex;justify-content:space-between;gap:6px}
.dshpet-meta span{white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.dshpet-actions{margin-top:7px;display:flex;gap:6px;align-items:center;flex-wrap:wrap}
.dshpet-btn{border:1.5px solid #c9d5f2;background:#f4f7ff;color:#33477f;border-radius:10px;font-size:11.5px;line-height:1;padding:5px 8px;cursor:pointer;transition:background .15s,border-color .15s}
.dshpet-btn:hover{background:#e6eeff;border-color:#9fb4e6}
.dshpet-btn[data-on="true"]{background:#1f3a8f;border-color:#1f3a8f;color:#fff}
.dshpet-badge{margin-left:auto;font-size:10.5px;color:#6b7aa5;background:#eef2fb;border-radius:8px;padding:3px 6px;white-space:nowrap}
.dshpet-badge[data-tone="warn"]{background:#fff1e0;color:#a2631a}
.dshpet-badge[data-tone="bad"]{background:#ffe8e8;color:#b02a2a}
.dshpet-sprite{position:relative;width:220px;height:183px;flex:none;cursor:pointer;touch-action:none;transition:transform .16s ease}
/* One single image, one single animation: a seam is physically impossible. */
.dshpet-stack{position:absolute;left:0;top:0;width:100%;height:100%;transform-origin:50% 97%;animation:dshpet-idle 5.6s ease-in-out infinite;will-change:transform;backface-visibility:hidden}
.dshpet-full{position:absolute;left:0;top:0;width:100%;height:100%;display:block;pointer-events:none;image-rendering:auto;transition:opacity .22s ease}
.dshpet-alt{opacity:0}
@keyframes dshpet-idle{0%,100%{transform:translateY(0) scale(1) rotate(0)}50%{transform:translateY(-4px) scale(1.01) rotate(-.45deg)}}
.dshpet-sprite[data-wag="true"] .dshpet-stack{animation-duration:2.6s}
.dshpet-sprite[data-mood="happy"]{animation:dshpet-bounce .5s cubic-bezier(.34,1.56,.64,1)}
@keyframes dshpet-bounce{0%{transform:scale(1)}35%{transform:scale(1.1,.92) rotate(-2deg)}70%{transform:scale(.96,1.05) rotate(1.5deg)}100%{transform:scale(1)}}
.dshpet-sprite[data-mood="annoyed"]{animation:dshpet-shake .4s ease-in-out}
@keyframes dshpet-shake{0%,100%{transform:translateX(0)}20%{transform:translateX(-6px) rotate(-1.6deg)}50%{transform:translateX(6px) rotate(1.6deg)}80%{transform:translateX(-3px)}}
.dshpet-sprite[data-mood="excited"]{animation:dshpet-spin .85s ease-in-out}
@keyframes dshpet-spin{0%{transform:rotate(0) scale(1)}45%{transform:rotate(190deg) scale(1.08)}100%{transform:rotate(360deg) scale(1)}}
.dshpet-sprite[data-mood="sleepy"] .dshpet-stack{animation-duration:9s;filter:brightness(.82) saturate(.8)}
@keyframes dshpet-doze{0%,100%{transform:translateY(2px) scale(.995)}50%{transform:translateY(6px) scale(1.008)}}
.dshpet-sprite:hover .dshpet-stack{animation-duration:3.4s}
.dshpet-sprite:hover{transform:scale(1.02)}
.dshpet-sprite[data-nomotion="true"] *{animation:none!important}
.dshpet-bar{margin-top:5px;height:7px;width:220px;border-radius:99px;background:#e7ecfa;overflow:hidden;box-shadow:inset 0 1px 2px rgba(20,40,90,.12)}
.dshpet-bar i{display:block;height:100%;border-radius:99px;background:linear-gradient(90deg,#7fb0ff,#3f6fe0);transition:width .4s ease}
.dshpet-hearts{position:absolute;left:0;top:0;width:220px;height:183px;pointer-events:none;overflow:visible}
.dshpet-particle{position:absolute;font-size:17px;line-height:1;animation:dshpet-float 1.15s ease-out forwards;will-change:transform,opacity}
@keyframes dshpet-float{0%{transform:translate(0,0) scale(.7);opacity:0}18%{opacity:1}100%{transform:translate(var(--dx),-62px) scale(1.15) rotate(var(--rot));opacity:0}}
.dshpet-zzz{position:absolute;right:26%;top:12%;font-size:13px;font-weight:700;color:#5c73ad;animation:dshpet-zzz 2.6s ease-in-out infinite}
@keyframes dshpet-zzz{0%{transform:translate(0,0);opacity:0}25%{opacity:.95}100%{transform:translate(16px,-28px);opacity:0}}
.dshpet-pill{display:flex;align-items:center;gap:7px;background:#fff;border:3px solid #1f3a8f;border-radius:99px;padding:4px 11px 4px 5px;box-shadow:0 8px 20px rgba(16,32,84,.2);cursor:pointer}
.dshpet-pill img{width:30px;height:30px;border-radius:50%;object-fit:cover;object-position:50% 30%}
.dshpet-pill b{font-size:13.5px;font-variant-numeric:tabular-nums;color:#1f3a8f}
.dshpet-help{position:absolute;right:0;bottom:196px;width:216px;background:#fff;border:3px solid #1f3a8f;border-radius:16px;padding:10px 12px;font-size:11.5px;line-height:1.7;color:#2b3b66;box-shadow:0 10px 24px rgba(16,32,84,.22)}
.dshpet-help kbd{background:#eef2fb;border-radius:5px;padding:1px 5px;font-family:inherit;font-size:11px;border:1px solid #d6dff5}
.dshpet-root[data-hidden="true"] *{animation-play-state:paused!important}
.dshpet-root[data-nomotion="true"] *,.dshpet-root[data-nomotion="true"] *::before,.dshpet-root[data-nomotion="true"] *::after{animation:none!important;transition:none!important}
@media (prefers-reduced-motion: reduce){.dshpet-root *{animation:none!important;transition:none!important}}
`;
		const tagId = "dsh-pet/widget.css";
		if (typeof document !== "undefined" && document.querySelector(`style[data-plugin-css=${JSON.stringify(tagId)}]`) === null) {
			const tag = document.createElement("style");
			tag.dataset.plugin = "dsh-pet";
			tag.dataset.pluginCss = tagId;
			tag.textContent = css;
			document.head.appendChild(tag);
		}
		//#endregion

		//#region constants
		const STORE_KEYS = {
			pos: "dsh-pet:pos",
			pets: "dsh-pet:pets",
			collapsed: "dsh-pet:collapsed:v2",
			sound: "dsh-pet:sound",
			motion: "dsh-pet:motion",
			last: "dsh-pet:last",
			help: "dsh-pet:help"
		};
		const BUILD = "v26-host-switch";
		const ASSET = "/pet-api/asset/";
		const SPRITE_W = 220;
		const SPRITE_H = 183;
		const BOX_W = 470; // bubble + gap + sprite
		const BOX_H = 206;
		const POLL_MS = 60_000;
		const SLEEP_AFTER_MS = 30_000;
		const ANNOY_WINDOW_MS = 4_000;
		const ANNOY_COUNT = 6;
		const STROKE_THROTTLE_MS = 420;
		const WAG_MS = 1_200;
		const AFFECTION_TITLES = ["初次见面", "认识的人", "朋友", "好朋友", "挚友", "灵魂搭子", "命运共同体", "本命"];
		const LINES = {
			idle: [
				"今天也在努力写代码呢～",
				"余额看着还挺安心，放心用吧！",
				"记得喝水哦，我盯着你呢。",
				"有我在，bug 不敢造次！",
				"代码写累了就摸摸我吧～",
				"尾巴会摇，说明心情不错～",
				"要不要让我看看今天的进度？"
			],
			happy: [
				"呜…好舒服～",
				"再摸一下嘛～",
				"嘻嘻，痒痒的…",
				"尾巴都摇起来了！",
				"手好暖…喜欢！"
			],
			annoyed: ["呜…别戳了啦！", "人家要生气了哦…", "再戳就咬你！", "尾巴都炸毛了！"],
			sleepy: ["Zzz…", "呼…呼…", "再…再睡五分钟…"],
			waking: ["呜哇！谁？…我、我没睡着！", "嗯…？发生什么了…"],
			worried: ["余额有点少了…要不要充一点？", "钱包在偷偷哭…", "省着点用，我心疼。"],
			panic: ["余额告急！！快救救钱包！", "只剩一点点了…我不敢说话了…", "再聊下去就要饿肚子了…"],
			excited: ["唔哦！转圈圈～", "哇！好开心！！", "最喜欢你了！"]
		};
		const HEART_GLYPHS = ["♥", "✦", "♪", "✧", "♥"];
		//#endregion

		//#region helpers
		function pick(list) {
			return list[Math.floor(Math.random() * list.length)];
		}

		function readStorage(key, fallback) {
			try {
				const raw = window.localStorage.getItem(key);
				return raw === null ? fallback : JSON.parse(raw);
			} catch {
				return fallback;
			}
		}

		function writeStorage(key, value) {
			try {
				window.localStorage.setItem(key, JSON.stringify(value));
			} catch {
				/* private mode: the pet simply forgets */
			}
		}

		function money(value, currency) {
			if (typeof value !== "number" || !Number.isFinite(value)) return "--";
			const symbol = currency === "USD" ? "$" : "¥";
			return `${symbol} ${value.toFixed(2)}`;
		}

		function clockText(iso) {
			if (typeof iso !== "string" || iso === "") return "--:--";
			const date = new Date(iso);
			if (Number.isNaN(date.getTime())) return "--:--";
			const pad = (n) => String(n).padStart(2, "0");
			return `${pad(date.getHours())}:${pad(date.getMinutes())}`;
		}

		function postEvent(type, detail) {
			try {
				const body = JSON.stringify({ type, detail: detail ?? null });
				if (typeof navigator !== "undefined" && typeof navigator.sendBeacon === "function") {
					navigator.sendBeacon("/pet-api/event", new Blob([body], { type: "application/json" }));
					return;
				}
				void fetch("/pet-api/event", { method: "POST", headers: { "content-type": "application/json" }, body, keepalive: true });
			} catch {
				/* telemetry must never break the widget */
			}
		}

		function isHidden() {
			return typeof document !== "undefined" && document.hidden === true;
		}

		function affectionTitle(pets) {
			const level = Math.min(AFFECTION_TITLES.length, 1 + Math.floor(pets / 10));
			return { level, title: AFFECTION_TITLES[level - 1] };
		}
		//#endregion

		//#region audio
		function makeVoice() {
			let ctx = null;
			return function blip(kind, enabled) {
				if (!enabled) return;
				try {
					const AudioCtor = window.AudioContext ?? window.webkitAudioContext;
					if (AudioCtor === undefined) return;
					if (ctx === null) ctx = new AudioCtor();
					const now = ctx.currentTime;
					const note = (type, from, to, duration, volume, delay) => {
						const osc = ctx.createOscillator();
						const gain = ctx.createGain();
						osc.type = type;
						osc.frequency.setValueAtTime(from, now + delay);
						if (to !== from) osc.frequency.exponentialRampToValueAtTime(to, now + delay + duration);
						gain.gain.setValueAtTime(0.0001, now + delay);
						gain.gain.exponentialRampToValueAtTime(volume, now + delay + 0.012);
						gain.gain.exponentialRampToValueAtTime(0.0001, now + delay + duration);
						osc.connect(gain).connect(ctx.destination);
						osc.start(now + delay);
						osc.stop(now + delay + duration + 0.02);
					};
					if (kind === "pet") note("sine", 760, 320, 0.16, 0.16, 0);
					else if (kind === "happy") {
						note("sine", 620, 900, 0.1, 0.14, 0);
						note("sine", 900, 1240, 0.14, 0.12, 0.09);
					} else if (kind === "annoyed") note("square", 220, 150, 0.13, 0.1, 0);
					else if (kind === "excited") {
						note("triangle", 520, 1040, 0.12, 0.14, 0);
						note("triangle", 780, 1560, 0.16, 0.12, 0.1);
					} else note("triangle", 880, 880, 0.06, 0.09, 0);
				} catch {
					/* audio is a bonus, never a requirement */
				}
			};
		}
		//#endregion

		/** The floating widget: layered character, speech bubble and petting. */
		function PetWidget() {
			const voice = react.useMemo(() => makeVoice(), []);
			const [state, setState] = react.useState(() => ({
				loading: true,
				error: null,
				balance: readStorage(STORE_KEYS.last, null),
				usage: { usedToday: 0 },
				fetchedAt: null,
				serverTime: null
			}));
			const [pets, setPets] = react.useState(() => readStorage(STORE_KEYS.pets, 0));
			const [mood, setMood] = react.useState("normal");
			const [line, setLine] = react.useState(() => pick(LINES.idle));
			const [particles, setParticles] = react.useState([]);
			const [pos, setPos] = react.useState(() => readStorage(STORE_KEYS.pos, null));
			const [collapsed, setCollapsed] = react.useState(() => readStorage(STORE_KEYS.collapsed, false));
			/**
			 * Master switch kept on the host (data/enabled.json). false = render nothing
			 * at all, which is what "关闭" means — deliberately different from 收起.
			 * Polling it means the desktop launcher can turn her back on without a refresh.
			 */
			const [enabledOn, setEnabledOn] = react.useState(true);
			const setEnabled = react.useCallback((next) => {
				setEnabledOn(next);
				try {
					void fetch("/pet-api/enabled", {
						method: "POST",
						headers: { "content-type": "application/json" },
						body: JSON.stringify({ enabled: next })
					});
				} catch {
					/* the local view already switched */
				}
				postEvent("enabled", next ? "on" : "off");
			}, []);
			react.useEffect(() => {
				let alive = true;
				const read = async () => {
					try {
						const res = await fetch("/pet-api/enabled", { cache: "no-store" });
						const body = await res.json();
						if (alive && body !== null && typeof body === "object" && typeof body.enabled === "boolean") {
							setEnabledOn((prev) => (prev === body.enabled ? prev : body.enabled));
						}
					} catch {
						/* offline: keep the current view */
					}
				};
				void read();
				const timer = window.setInterval(read, 4000);
				return () => { alive = false; window.clearInterval(timer); };
			}, []);
			const [sound, setSound] = react.useState(() => readStorage(STORE_KEYS.sound, true));
			const [motion, setMotion] = react.useState(() => readStorage(STORE_KEYS.motion, true));
			const [hidden, setHidden] = react.useState(() => isHidden());
			const [help, setHelp] = react.useState(() => readStorage(STORE_KEYS.help, false));
			const [stroking, setStroking] = react.useState(false);
			const [wag, setWag] = react.useState(false);
			const [fluster, setFluster] = react.useState(false);
			const [shy, setShy] = react.useState(false);
			const [pin, setPin] = react.useState(null);
			const [bubblePop, setBubblePop] = react.useState(false);
			const [happiness, setHappiness] = react.useState(68);

			const moodRef = react.useRef("normal");
			const petTimesRef = react.useRef([]);
			const lastStrokeRef = react.useRef(0);
			const lastActiveRef = react.useRef(Date.now());
			const moodTimerRef = react.useRef(null);
			const wagTimerRef = react.useRef(null);
			const flusterTimerRef = react.useRef(null);
			const shyTimerRef = react.useRef(null);
			const strokeCountRef = react.useRef(0);
			const dragRef = react.useRef(null);
			const rootRef = react.useRef(null);
			const collapseRef = react.useRef(collapsed);
			const soundRef = react.useRef(sound);
			const balanceTotalRef = react.useRef(null);

			collapseRef.current = collapsed;
			soundRef.current = sound;

			const setMoodBoth = react.useCallback((next) => {
				moodRef.current = next;
				setMood(next);
			}, []);

			const wagTail = react.useCallback(() => {
				setWag(true);
				if (wagTimerRef.current !== null) window.clearTimeout(wagTimerRef.current);
				wagTimerRef.current = window.setTimeout(() => setWag(false), WAG_MS);
			}, []);

			// brief switch to the flustered expression (sweat drops + >< eyes)
			const flusterFor = react.useCallback((ms) => {
				setFluster(true);
				if (flusterTimerRef.current !== null) window.clearTimeout(flusterTimerRef.current);
				flusterTimerRef.current = window.setTimeout(() => setFluster(false), ms ?? 4200);
			}, []);

			// brief switch to the shy expression (blush + hugging the tail)
			const shyFor = react.useCallback((ms) => {
				setShy(true);
				if (shyTimerRef.current !== null) window.clearTimeout(shyTimerRef.current);
				shyTimerRef.current = window.setTimeout(() => setShy(false), ms ?? 2000);
			}, []);

			const addParticles = react.useCallback((count, glyphs) => {
				if (isHidden()) return;
				const pool = glyphs ?? HEART_GLYPHS;
				const batch = [];
				for (let i = 0; i < count; i += 1) {
					batch.push({
						id: `${Date.now()}-${i}-${Math.random().toString(36).slice(2, 6)}`,
						glyph: pick(pool),
						left: 24 + Math.random() * 120,
						top: 40 + Math.random() * 70,
						dx: `${Math.round((Math.random() - 0.5) * 52)}px`,
						rot: `${Math.round((Math.random() - 0.5) * 70)}deg`,
						delay: `${Math.round(Math.random() * 160)}ms`,
						color: pick(["#ff6f91", "#ff9ec4", "#7fb0ff", "#ffd166", "#8ce0c0"])
					});
				}
				setParticles((current) => [...current, ...batch]);
				window.setTimeout(() => {
					const ids = new Set(batch.map((item) => item.id));
					setParticles((current) => current.filter((item) => !ids.has(item.id)));
				}, 1500);
			}, []);

			const say = react.useCallback((text, pop = true) => {
				setLine(text);
				if (pop) {
					setBubblePop(false);
					window.setTimeout(() => setBubblePop(true), 16);
				}
			}, []);

			const loadState = react.useCallback(async (force) => {
				try {
					const response = await fetch(force === true ? "/pet-api/refresh" : "/pet-api/state", force === true ? { method: "POST" } : undefined);
					const payload = await response.json();
					setState({
						loading: false,
						error: payload.error ?? null,
						balance: payload.balance ?? null,
						usage: payload.usage ?? { usedToday: 0 },
						fetchedAt: payload.fetchedAt ?? null,
						serverTime: payload.serverTime ?? null
					});
					if (payload.balance !== null && payload.balance !== undefined) writeStorage(STORE_KEYS.last, payload.balance);
					return payload;
				} catch (error) {
					setState((current) => ({ ...current, loading: false, error: `无法连接余额接口：${String(error && error.message ? error.message : error)}` }));
					postEvent("error", String(error && error.message ? error.message : error));
					return null;
				}
			}, []);

			react.useEffect(() => {
				postEvent("mount", `${BUILD} ${window.innerWidth}x${window.innerHeight}`);
				void loadState(false);
				const timer = window.setInterval(() => void loadState(false), POLL_MS);
				return () => window.clearInterval(timer);
			}, [loadState]);

			react.useEffect(() => {
				const place = () => {
					setPos((current) => {
						const width = collapseRef.current ? 150 : BOX_W;
						const next = current === null
							? { x: window.innerWidth - width - 24, y: window.innerHeight - BOX_H - 14 }
							: { x: Math.min(Math.max(0, current.x), Math.max(0, window.innerWidth - width)), y: Math.min(Math.max(0, current.y), Math.max(0, window.innerHeight - BOX_H)) };
						return next;
					});
				};
				place();
				window.addEventListener("resize", place);
				return () => window.removeEventListener("resize", place);
			}, []);

			react.useEffect(() => writeStorage(STORE_KEYS.pos, pos), [pos]);
			react.useEffect(() => writeStorage(STORE_KEYS.pets, pets), [pets]);
			react.useEffect(() => writeStorage(STORE_KEYS.collapsed, collapsed), [collapsed]);
			react.useEffect(() => writeStorage(STORE_KEYS.sound, sound), [sound]);
			react.useEffect(() => writeStorage(STORE_KEYS.motion, motion), [motion]);
			react.useEffect(() => writeStorage(STORE_KEYS.help, help), [help]);
			react.useEffect(() => {
				if (state.balance !== null && state.balance !== undefined) writeStorage(STORE_KEYS.last, state.balance);
			}, [state.balance]);

			// a background tab must not keep animating
			react.useEffect(() => {
				const onVisibility = () => setHidden(isHidden());
				document.addEventListener("visibilitychange", onVisibility);
				return () => document.removeEventListener("visibilitychange", onVisibility);
			}, []);

			react.useEffect(() => {
				const timer = window.setInterval(() => setHappiness((value) => Math.max(12, value - 0.35)), 30_000);
				return () => window.clearInterval(timer);
			}, []);

			react.useEffect(() => {
				const timer = window.setInterval(() => {
					if (Date.now() - lastActiveRef.current < SLEEP_AFTER_MS) return;
					if (moodRef.current === "sleepy" || moodRef.current === "annoyed") return;
					setMoodBoth("sleepy");
					say(pick(LINES.sleepy), false);
				}, 2_000);
				return () => window.clearInterval(timer);
			}, [say, setMoodBoth]);

			const balanceTotal = state.balance === null || state.balance === undefined ? null : state.balance.total;
			const currency = state.balance === null || state.balance === undefined ? "CNY" : state.balance.currency;
			balanceTotalRef.current = balanceTotal;

			// idle chatter keeps a mood-appropriate line rotating
			react.useEffect(() => {
				const timer = window.setInterval(() => {
					if (isHidden()) return;
					if (Date.now() - lastActiveRef.current < 20_000) return;
					const current = moodRef.current;
					if (current === "annoyed" || current === "excited") return;
					if (current === "sleepy") {
						say(pick(LINES.sleepy), false);
						return;
					}
					const total = balanceTotalRef.current;
					if (total !== null && total < 3) say(pick(LINES.panic), false);
					else if (total !== null && total < 10) say(pick(LINES.worried), false);
					else say(pick(LINES.idle), false);
				}, 21_000);
				return () => window.clearInterval(timer);
			}, [say]);

			react.useEffect(() => {
				if (balanceTotal === null || moodRef.current === "sleepy" || moodRef.current === "annoyed") return;
				if (balanceTotal < 3) {
					setMoodBoth("panic");
					say(pick(LINES.panic), false);
					flusterFor(5200);
				} else if (balanceTotal < 10) {
					setMoodBoth("worried");
					say(pick(LINES.worried), false);
					flusterFor(3600);
				}
			}, [balanceTotal, say, setMoodBoth, flusterFor]);

			const resetPosition = react.useCallback(() => {
				const width = collapseRef.current ? 150 : BOX_W;
				setPos({
					x: Math.max(0, window.innerWidth - width - 24),
					y: Math.max(0, window.innerHeight - BOX_H - 14)
				});
				setCollapsed(false);
				setHelp(false);
				setMoodBoth("happy");
				say("我回来啦！");
				wagTail();
				addParticles(5, ["✦", "♥"]);
				window.setTimeout(() => setMoodBoth("normal"), 1_400);
			}, [addParticles, say, setMoodBoth, shyFor, wagTail]);

			const markActive = react.useCallback(() => {
				const wasSleeping = moodRef.current === "sleepy";
				lastActiveRef.current = Date.now();
				if (wasSleeping) {
					setMoodBoth("happy");
					say(pick(LINES.waking));
					shyFor(2000);
					wagTail();
					addParticles(3);
					if (moodTimerRef.current !== null) window.clearTimeout(moodTimerRef.current);
					moodTimerRef.current = window.setTimeout(() => setMoodBoth("normal"), 1_600);
				}
			}, [addParticles, say, setMoodBoth, shyFor, wagTail]);

			const doPet = react.useCallback(() => {
				const now = Date.now();
				lastActiveRef.current = now;
				const recent = petTimesRef.current.filter((at) => now - at < ANNOY_WINDOW_MS);
				recent.push(now);
				petTimesRef.current = recent;
				setPets((value) => value + 1);
				setHappiness((value) => Math.min(100, value + 3.4));
				wagTail();
				if (moodTimerRef.current !== null) window.clearTimeout(moodTimerRef.current);
				if (recent.length >= ANNOY_COUNT) {
					setMoodBoth("annoyed");
					say(pick(LINES.annoyed));
					voice("annoyed", soundRef.current);
					postEvent("pet", "annoyed");
					moodTimerRef.current = window.setTimeout(() => {
						petTimesRef.current = [];
						setMoodBoth("normal");
					}, 2_000);
					return;
				}
				if (recent.length === 5) flusterFor(2400);
				const excited = recent.length === 3;
				setMoodBoth(excited ? "excited" : "happy");
				say(pick(excited ? LINES.excited : LINES.happy));
				addParticles(excited ? 9 : 2 + Math.floor(Math.random() * 3), excited ? ["♥", "✦", "★", "♪"] : undefined);
				voice(excited ? "excited" : "pet", soundRef.current);
				postEvent("pet", excited ? "excited" : "normal");
				moodTimerRef.current = window.setTimeout(() => setMoodBoth("normal"), excited ? 900 : 1_200);
			}, [addParticles, flusterFor, say, setMoodBoth, voice, wagTail]);

			const doStroke = react.useCallback(() => {
				const now = Date.now();
				lastActiveRef.current = now;
				if (now - lastStrokeRef.current < STROKE_THROTTLE_MS) return;
				lastStrokeRef.current = now;
				if (moodRef.current === "annoyed" || moodRef.current === "sleepy") return;
				setHappiness((value) => Math.min(100, value + 1.1));
				strokeCountRef.current += 1;
				if (strokeCountRef.current % 4 === 0) shyFor(2200);
				if (Math.random() < 0.25) wagTail();
				addParticles(1, ["♥", "♪", "✧"]);
				if (Math.random() < 0.34) say(pick(LINES.happy));
				postEvent("stroke");
			}, [addParticles, say, shyFor, wagTail]);

			const doRefresh = react.useCallback(async () => {
				lastActiveRef.current = Date.now();
				voice("click", soundRef.current);
				say("正在刷新余额…", false);
				const payload = await loadState(true);
				if (payload !== null && payload.ok === true) {
					setMoodBoth("happy");
					say("刷新好啦！余额已更新～");
					wagTail();
					addParticles(4, ["✦", "✧"]);
					moodTimerRef.current = window.setTimeout(() => setMoodBoth("normal"), 1_400);
				} else {
					say(payload !== null && payload.error ? `刷新失败：${payload.error}` : "刷新失败了…");
				}
			}, [addParticles, loadState, say, setMoodBoth, voice, wagTail]);

			const onPointerDown = react.useCallback((event) => {
				if (event.button !== 0) return;
				dragRef.current = {
					pointerId: event.pointerId,
					startX: event.clientX,
					startY: event.clientY,
					originX: pos === null ? 0 : pos.x,
					originY: pos === null ? 0 : pos.y,
					moved: 0
				};
				event.currentTarget.setPointerCapture?.(event.pointerId);
			}, [pos]);

			const onPointerMove = react.useCallback((event) => {
				const drag = dragRef.current;
				if (drag === null || drag.pointerId !== event.pointerId) return;
				const dx = event.clientX - drag.startX;
				const dy = event.clientY - drag.startY;
				drag.moved = Math.max(drag.moved, Math.abs(dx) + Math.abs(dy));
				if (drag.moved < 5) return;
				const nextX = Math.min(Math.max(-SPRITE_W / 2, drag.originX + dx), window.innerWidth - SPRITE_W / 2);
				const nextY = Math.min(Math.max(-10, drag.originY + dy), window.innerHeight - 60);
				setPos({ x: nextX, y: nextY });
			}, []);

			const onPointerUp = react.useCallback((event) => {
				const drag = dragRef.current;
				dragRef.current = null;
				if (drag === null) return;
				event.currentTarget.releasePointerCapture?.(event.pointerId);
				if (drag.moved < 5) {
					if (collapseRef.current) {
						setCollapsed(false);
						return;
					}
					doPet();
				} else {
					postEvent("move", `${Math.round(drag.moved)}px`);
				}
			}, [doPet]);

			const meta = affectionTitle(pets);
			const tone = balanceTotal === null ? "warn" : balanceTotal < 3 ? "bad" : balanceTotal < 10 ? "warn" : "ok";
			const usedText = typeof state.usage.usedToday === "number" ? state.usage.usedToday : 0;
			const statusText = state.error !== null && state.error !== undefined
				? state.error
				: `更新于 ${clockText(state.fetchedAt)} · ${meta.title} Lv.${meta.level}`;
			/** which of the four drawings is on screen: dozing off, shy, flustered, normal.
			 *  A manual pin (the 表情 button) overrides the automatic choice. */
			const autoExpression = mood === "sleepy"
				? "sleepy"
				: (mood === "excited" || shy)
					? "shy"
					: (mood === "annoyed" || fluster)
					? "panic"
					: "normal";
			const EXPRESSION_ORDER = [null, "shy", "normal", "panic", "sleepy"];
			const EXPRESSION_NAME = { normal: "常态", panic: "慌张", sleepy: "偷懒", shy: "害羞" };
			const expression = pin ?? autoExpression;
			const cycleExpression = () => {
				const next = EXPRESSION_ORDER[(EXPRESSION_ORDER.indexOf(pin) + 1) % EXPRESSION_ORDER.length];
				setPin(next);
				postEvent("expression", next === null ? "auto" : next);
			};
			const drawOf = (name) => ({ opacity: expression === name ? 1 : 0 });

			const style = { left: `${pos === null ? 0 : pos.x}px`, top: `${pos === null ? 0 : pos.y}px`, visibility: pos === null ? "hidden" : "visible" };
			const rootAttrs = {
				ref: rootRef,
				className: "dshpet-root",
				style,
				"data-dragging": dragRef.current === null ? "false" : "true",
				"data-hidden": hidden ? "true" : "false",
				"data-nomotion": motion ? "false" : "true"
			};

			const particleLayer = h(
				"div",
				{ className: "dshpet-hearts", "aria-hidden": "true" },
				particles.map((item) => h("span", {
					key: item.id,
					className: "dshpet-particle",
					style: { left: `${item.left}px`, top: `${item.top}px`, color: item.color, animationDelay: item.delay, "--dx": item.dx, "--rot": item.rot }
				}, item.glyph))
			);

			if (!enabledOn) {
				// 关闭状态：连小圆牌都不渲染，直到宿主开关被重新打开
				return null;
			}

			if (collapsed) {
				return h(
					"div",
					rootAttrs,
					h(
						"div",
						{
							className: "dshpet-pill",
							role: "button",
							tabIndex: 0,
							title: "点一下叫出看板娘 · 双击刷新余额 · 按住可拖动",
							onPointerDown,
							onPointerMove,
							onPointerUp,
							onDoubleClick: () => void doRefresh(),
							onKeyDown: (event) => { if (event.key === "Enter" || event.key === " ") setCollapsed(false); }
						},
						h("img", { src: `${ASSET}pet20-avatar.png`, alt: "看板娘" }),
						h("b", null, money(balanceTotal, currency))
					)
				);
			}

			return h(
				"div",
				rootAttrs,
				h(
					"div",
					{ className: `dshpet-bubble${bubblePop ? " dshpet-pop" : ""}`, onAnimationEnd: () => setBubblePop(false) },
					h("div", { className: "dshpet-title" }, "DeepSeek 余额"),
					h("div", { className: "dshpet-amount" }, money(balanceTotal, currency)),
					h("div", { className: "dshpet-used" }, "今日已用 ", h("b", null, money(usedText, currency))),
					h("div", { className: "dshpet-say" }, line),
					h(
						"div",
						{ className: "dshpet-meta" },
						h("span", { title: statusText }, statusText),
						h("span", { className: "dshpet-badge", "data-tone": tone }, `被摸 ${pets} 次`)
					),
					h(
						"div",
						{ className: "dshpet-actions" },
						h("button", { className: "dshpet-btn", type: "button", onClick: () => void doRefresh(), title: "立即刷新余额" }, "刷新"),
						h("button", {
							className: "dshpet-btn",
							type: "button",
							"data-on": sound ? "true" : "false",
							onClick: () => setSound((value) => !value),
							title: sound ? "关闭音效" : "打开音效"
						}, sound ? "音效开" : "音效关"),
						h("button", {
							className: "dshpet-btn",
							type: "button",
							"data-on": motion ? "true" : "false",
							onClick: () => setMotion((value) => !value),
							title: motion ? "关闭动效（省电）" : "开启动效"
						}, motion ? "动效开" : "动效关"),
						h("button", {
							className: "dshpet-btn",
							type: "button",
							"data-on": pin === null ? "false" : "true",
							onClick: cycleExpression,
							title: "点一下看害羞；再点依次切换 常态 → 慌张 → 偷懒 → 自动"
						}, pin === null ? "表情" : EXPRESSION_NAME[pin]),
						h("button", {
							className: "dshpet-btn",
							type: "button",
							onClick: () => setHelp((value) => !value),
							title: "玩法说明"
						}, "玩法"),
						h("button", { className: "dshpet-btn", type: "button", onClick: () => setEnabled(false), title: "彻底关闭看板娘（用桌面「启动看板娘.exe」可再打开）" }, "关闭"),
						h("button", { className: "dshpet-btn", type: "button", onClick: () => setCollapsed(true), title: "收成小圆牌" }, "收起")
					)
				),
				h(
					"div",
					{ style: { position: "relative" } },
					help ? h(
						"div",
						{ className: "dshpet-help" },
						h("div", null, h("kbd", null, "单击"), " 摸摸头（连点会生气）"),
						h("div", null, h("kbd", null, "双击"), " 刷新余额"),
						h("div", null, h("kbd", null, "悬停"), " 来回抚摸会冒心心"),
						h("div", null, h("kbd", null, "拖动"), " 挪到任意位置"),
						h("div", null, h("kbd", null, "连点3下"), " 有惊喜"),
						h("button", { className: "dshpet-btn", type: "button", style: { marginTop: 8 }, onClick: resetPosition }, "回到原位"),
						h("div", { style: { marginTop: 6, color: "#7c89ab" } }, "呆毛和尾巴会一直动；摸她尾巴会摇得更快。今天已用金额按余额变化估算。")
					) : null,
					h(
						"div",
						{
							className: "dshpet-sprite",
							"data-mood": mood,
							"data-stroking": stroking ? "true" : "false",
							"data-wag": wag ? "true" : "false",
							"data-nomotion": motion ? "false" : "true",
							role: "button",
							tabIndex: 0,
							"aria-label": "看板娘：单击摸摸，双击刷新余额",
							title: "单击摸摸 · 双击刷新 · 拖动挪位置",
							onPointerDown,
							onPointerMove: (event) => {
								onPointerMove(event);
								if (dragRef.current === null) doStroke();
							},
							onPointerUp,
							onPointerEnter: () => {
								setStroking(true);
								markActive();
							},
							onPointerLeave: () => {
								setStroking(false);
								if (dragRef.current !== null) dragRef.current = null;
							},
							onDoubleClick: () => void doRefresh(),
							onKeyDown: (event) => {
								if (event.key === "Enter" || event.key === " ") {
									event.preventDefault();
									doPet();
								}
							}
						},
						h("div", { className: "dshpet-stack" },
							h("img", { className: "dshpet-full", src: `${ASSET}pet20-full.png`, style: drawOf("normal"), alt: "看板娘", draggable: false }),
							h("img", { className: "dshpet-full", src: `${ASSET}pet20-panic.png`, style: drawOf("panic"), alt: "", draggable: false }),
							h("img", { className: "dshpet-full", src: `${ASSET}pet20-sleepy.png`, style: drawOf("sleepy"), alt: "", draggable: false }),
							h("img", { className: "dshpet-full", src: `${ASSET}pet22-shy.png`, style: drawOf("shy"), alt: "", draggable: false }),
							particleLayer
						)
					),
					h("div", { className: "dshpet-bar", title: `心情 ${Math.round(happiness)}/100` }, h("i", { style: { width: `${Math.round(happiness)}%` } }))
				)
			);
		}

		/** Client plugin body: one overlay registration. */
		const inject = ["slots"];
		function apply(ctx) {
			ctx.effect(
				() => ctx.slots.inject("shell.overlay", () => ctx.slots.register({
					name: "shell.overlay",
					id: "dsh-pet",
					order: 40
				}, PetWidget)),
				"dsh-pet: overlay widget"
			);
		}

		exports.apply = apply;
		exports.inject = inject;
		return module.exports;
	}
});
