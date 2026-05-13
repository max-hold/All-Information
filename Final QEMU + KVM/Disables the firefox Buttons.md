# Disables the minimize, maximize/restore, and close buttons
```
cat > firefox-alpine-button-disables.sh << 'SCRIPT'
#!/bin/sh
set -e

# Find all profiles
PROFILES=$(find ~/.mozilla/firefox -maxdepth 1 -name "*.default*" -type d)

if [ -z "$PROFILES" ]; then
    echo "No profiles found. Starting Firefox once to create default profile..."
    firefox --headless &
    sleep 3
    killall firefox 2>/dev/null || true
    PROFILES=$(find ~/.mozilla/firefox -maxdepth 1 -name "*.default*" -type d)
fi

for PROFILE_DIR in $PROFILES; do
    echo "Profile: $PROFILE_DIR"
    
    # Create chrome folder
    mkdir -p "$PROFILE_DIR/chrome"
    
    # Write userChrome.css
    cat > "$PROFILE_DIR/chrome/userChrome.css" << 'USERCHROME'
@namespace url("http://www.mozilla.org/keymaster/gatekeeper/there.is.only.xul");

/* 1. Hide minimize, maximize, close buttons */
.titlebar-buttonbox-container {
    display: none !important;
}

/* 2. Hide the Menu Bar (File, Edit, etc.) */
#toolbar-menubar {
    display: none !important;
}

/* 3. Optional: Make the titlebar area less interactive (helps with double-click) */
#titlebar {
    -moz-window-dragging: no-drag !important;
}

/* 4. Ensure Tabs stay visible and usable */
#TabsToolbar {
    visibility: visible !important;
    min-height: 30px !important;
}

/* Extra safety: Prevent some dragging on nav toolbox */
#navigator-toolbox {
    -moz-window-dragging: no-drag !important;
}
USERCHROME

    # Ensure the preference is enabled
    PREF_FILE="$PROFILE_DIR/prefs.js"
    if [ -f "$PREF_FILE" ]; then
        if grep -q "toolkit.legacyUserProfileCustomizations.stylesheets" "$PREF_FILE"; then
            sed -i 's/.*toolkit.legacyUserProfileCustomizations.stylesheets.*/user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);/' "$PREF_FILE"
        else
            echo 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);' >> "$PREF_FILE"
        fi
    else
        echo 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);' > "$PREF_FILE"
    fi
done

SCRIPT
```
```
chmod +x firefox-alpine-button-disables.sh
./firefox-alpine-button-disables.sh
```

```
killall firefox 2>/dev/null || true
firefox 
# OR RUN THE AUTOSTART FIREFOX PROCESS
```
