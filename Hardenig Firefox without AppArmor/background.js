"use strict";

// KIOSK GUARD — background.js //
// CONFIGURATION — only edit values inside this block //

// URL capture  : every tab's address bar URL is captured + logged
// Download toggle : downloads blocked by default (also in firefox.cfg)
// Download size limit : cap max file size per download


// Download toggle
// false = all downloads blocked (default)
// true  = downloads allowed (size limit below still applies)
const DOWNLOADS_ENABLED = false;                         // TOGGLE THIS LINE

// Download size limit (only applies when DOWNLOADS_ENABLED = true)
// Change the number to set a different cap in gigabytes.
const MAX_DOWNLOAD_SIZE_GB    = 5;                       // CHANGE THIS VALUE
const MAX_DOWNLOAD_SIZE_BYTES = MAX_DOWNLOAD_SIZE_GB * 1024 * 1024 * 1024;

// Host log endpoint
// URL captured events are POST-ed here in real time.
// Leave as-is until the host controller service is running.
// Failed sends are silently ignored — local log is always kept.
const LOG_ENDPOINT = "http://127.0.0.1:8888/log";       // SET YOUR HOST ENDPOINT

// Local storage log (always on — independent of the endpoint above)
const LOG_TO_STORAGE      = true;
const MAX_URL_LOG_ENTRIES = 10000;   // trim oldest when over this count
const MAX_EVT_LOG_ENTRIES = 5000;




// URL Capture //
//
// Listens to three tab events so we capture every navigation:
//   tab_created   → a new tab was opened (could have a URL immediately)
//   tab_updated   → address bar URL changed (typed URL, clicked link, redirect)
//   tab_activated → user switched focus to an existing ta

function captureURL(tabId, url, event) {
  // Skip internal browser pages
  if (!url)                          return;
  if (url.startsWith("about:"))      return;
  if (url.startsWith("moz-extension:")) return;
  if (url.startsWith("chrome:"))     return;
  if (url === "")                    return;

  const entry = {
    timestamp : new Date().toISOString(),
    type      : "url_visit",
    event,                  // tab_created | tab_updated | tab_activated
    tabId,
    url,
  };

  storeEntry("urlLog", entry, MAX_URL_LOG_ENTRIES);
  sendToHost(entry);
}

// New tab opened
browser.tabs.onCreated.addListener((tab) => {
  if (tab.url) captureURL(tab.id, tab.url, "tab_created");
});

// Address bar URL changed (navigation, redirect, pushState)
browser.tabs.onUpdated.addListener((tabId, changeInfo) => {
  if (changeInfo.url) captureURL(tabId, changeInfo.url, "tab_updated");
});

// User switched to a different tab
browser.tabs.onActivated.addListener(({ tabId }) => {
  browser.tabs.get(tabId)
    .then((tab) => { if (tab.url) captureURL(tab.id, tab.url, "tab_activated"); })
    .catch(() => {});
});



// Download Control //
//
// Fires on every download attempt before the file is saved.
// Check 1 (Feature 2): if DOWNLOADS_ENABLED = false → cancel immediately.
// Check 2 (Feature 3): if file size > MAX_DOWNLOAD_SIZE_BYTES → cancel.
//
// READ IT //  
// Note: totalBytes = -1 means server sent no Content-Length header.
// In that case we cannot know the size upfront → allow through. The Demon file monitor will catch it post-download.

browser.downloads.onCreated.addListener((item) => {

  //  Check 1: Global toggle (Feature 2) 
  if (!DOWNLOADS_ENABLED) {
    cancelDownload(item.id);
    logEvent("download_blocked_toggle", {
      url      : item.url,
      filename : item.filename,
      reason   : "Downloads are disabled by policy.",
    });
    return;
  }

  //  Check 2: Size limit (Feature 3) 
  if (item.totalBytes > 0 && item.totalBytes > MAX_DOWNLOAD_SIZE_BYTES) {
    cancelDownload(item.id);

    const actualMB = (item.totalBytes / (1024 * 1024)).toFixed(1);

    logEvent("download_blocked_size", {
      url      : item.url,
      filename : item.filename,
      actualMB,
      limitGB  : MAX_DOWNLOAD_SIZE_GB,
      reason   : `File is ${actualMB} MB — exceeds the ${MAX_DOWNLOAD_SIZE_GB} GB limit.`,
    });
    return;
  }

  // Both checks passed — download proceeds normally
  logEvent("download_allowed", {
    url      : item.url,
    filename : item.filename,
    sizeMB   : item.totalBytes > 0
                 ? (item.totalBytes / (1024 * 1024)).toFixed(1)
                 : "unknown",
  });
});

// Cancel and remove from download manager UI
function cancelDownload(id) {
  browser.downloads.cancel(id)
    .then(() => browser.downloads.erase({ id }))
    .catch(() => {});
}

// Append entry to a named array in extension local storage.
// Trims oldest entries when the cap is reached.
function storeEntry(key, entry, maxEntries) {
  if (!LOG_TO_STORAGE) return;
  browser.storage.local.get(key).then((result) => {
    const log = result[key] || [];
    log.push(entry);
    if (log.length > maxEntries) log.splice(0, log.length - maxEntries);
    browser.storage.local.set({ [key]: log });
  }).catch(() => {});
}

// Log a non-URL event (blocked downloads, allowed downloads, errors)
function logEvent(type, data) {
  const entry = { timestamp: new Date().toISOString(), type, ...data };
  storeEntry("eventLog", entry, MAX_EVT_LOG_ENTRIES);
  sendToHost(entry);
}

// POST a log entry to the host controller.
// Failures are silently ignored — local storage is always the fallback.
function sendToHost(entry) {
  fetch(LOG_ENDPOINT, {
    method  : "POST",
    headers : { "Content-Type": "application/json" },
    body    : JSON.stringify(entry),
  }).catch(() => {});
}
