// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html";
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import topbar from "../vendor/topbar.cjs";

// Session hooks from agents_web (used by cross-app mounted SessionsLive.Index)
import { SessionLogHook } from "../../../agents_web/assets/js/presentation/hooks/session-log-hook";
import { SessionFormHook } from "../../../agents_web/assets/js/presentation/hooks/session-form-hook";
import { SessionOptimisticStateHook } from "../../../agents_web/assets/js/presentation/hooks/session-optimistic-state-hook";
import { TriageLaneDndHook } from "../../../agents_web/assets/js/presentation/hooks/triage-lane-dnd-hook";
import { DurationTimerHook } from "../../../agents_web/assets/js/presentation/hooks/duration-timer-hook";
import { ConcurrencyLimitHook } from "../../../agents_web/assets/js/presentation/hooks/concurrency-limit-hook";
import { WarmCacheLimitHook } from "../../../agents_web/assets/js/presentation/hooks/warm-cache-limit-hook";
// Flash auto-hide hook from jarga_web
import { FlashHook } from "../../../jarga_web/assets/js/presentation/hooks/flash-hook";

// Extend Window interface for custom properties
declare global {
  interface Window {
    liveSocket: LiveSocket;
  }
}

// Hooks
const Hooks = {
  ScrollToHash: {
    mounted() {
      this.scrollToHash();
    },
    updated() {
      this.scrollToHash();
    },
    scrollToHash() {
      const hash = window.location.hash;
      if (hash) {
        // Small delay to let the DOM settle after LiveView patch
        requestAnimationFrame(() => {
          const el = document.querySelector(hash);
          if (el) {
            el.scrollIntoView({ behavior: "smooth", block: "start" });
          }
        });
      }
    },
  },
  SessionLog: SessionLogHook,
  SessionForm: SessionFormHook,
  SessionOptimisticState: SessionOptimisticStateHook,
  TriageLaneDnd: TriageLaneDndHook,
  DurationTimer: DurationTimerHook,
  ConcurrencyLimit: ConcurrencyLimitHook,
  WarmCacheLimit: WarmCacheLimitHook,
  AutoHideFlash: FlashHook,
};

const csrfTokenElement = document.querySelector("meta[name='csrf-token']");
const csrfToken = csrfTokenElement?.getAttribute("content");
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
  hooks: Hooks,
});

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });
window.addEventListener("phx:page-loading-start", (_info) => topbar.show(300));
window.addEventListener("phx:page-loading-stop", (_info) => topbar.hide());

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation
window.liveSocket = liveSocket;
