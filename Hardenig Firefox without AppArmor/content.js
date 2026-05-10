"use strict";


// KIOSK GUARD — content.js
//

// Disable all keyboard shortcuts //
// Runs at document_start on every page and every iframe.
// Intercepts keydown/keyup at window level with `useCapture=true —`
// this means our handler fires BEFORE any page script can respond. this can help to new Features like website flag.



// Edit this section to allow specific keys back //
// Ctrl/Cmd combos that are ALLOWED to pass through.
// Everything else with Ctrl is blocked.
// allow select-all, copy, paste, cut
const ALLOWED_CTRL_KEYS = ["a", "c", "v", "x"];        // ← EDIT ALLOWED COMBOS

// Set true to block EVERY Ctrl combination including copy/paste.
const BLOCK_ALL_CTRL = false;                            // ← true = block copy/paste too

// Function keys to block.
const BLOCKED_FUNCTION_KEYS = [
  "F1","F2","F3","F4","F5","F6",
  "F7","F8","F9","F10","F11","F12"
];

// Block the Escape key.
// user cannot dismiss dialogs or exit fullscreen with Escape.
const BLOCK_ESCAPE = true;                               // ← SET false TO ALLOW ESCAPE




// EVENT INTERCEPTION //
// Both keydown and keyup are captured so no shortcut slips through on keyup.
window.addEventListener("keydown", handleKey, true);
window.addEventListener("keyup",   handleKey, true);


function handleKey(event) {
  const ctrl  = event.ctrlKey || event.metaKey;
  const alt   = event.altKey;
  const key   = event.key;
  const keyLo = key.toLowerCase();

  // Block ALL Alt combinations 
  // This covers: Alt+F4, Alt+Left (back), Alt+Right (forward),
  // Alt+D (address bar focus), Alt+Home, Alt+Tab context leakage, etc.
  if (alt) {
    suppress(event);
    return;
  }

  //  Ctrl / Cmd combinations 
  if (ctrl) {
    if (BLOCK_ALL_CTRL) {
      suppress(event);
      return;
    }
    // Block everything except allowed keys
    if (!ALLOWED_CTRL_KEYS.includes(keyLo)) {
      suppress(event);
      return;
    }
    return;
  }

  // Function keys 
  if (BLOCKED_FUNCTION_KEYS.includes(key)) {
    suppress(event);
    return;
  }

  // Escape 
  if (BLOCK_ESCAPE && key === "Escape") {
    suppress(event);
    return;
  }
}


// Hard stop — cancels event and prevents it reaching any other handler
function suppress(event) {
  event.preventDefault();
  event.stopPropagation();
  event.stopImmediatePropagation();
}


// NOTE: Browser-chrome shortcuts (Ctrl+T, Ctrl+W, Ctrl+L, Ctrl+Tab) are
// handled by Firefox itself — not reachable from a content script.
// Those are covered by:
//   • policies.json → DisableDeveloperTools (blocks Ctrl+Shift+I, F12)
//   • Firefox --kiosk flag → disables Ctrl+W, Ctrl+Q, Ctrl+N
//   • policies.json → BlockAboutConfig (blocks Ctrl+L → about:config)
// All three layers together cover the full shortcut surface.
