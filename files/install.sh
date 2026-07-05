#!/bin/sh
# install.sh - Port Labels for LuCI
# Zyxel GS1900-24HP (rtl838x) / OpenWrt 24.10.x and 25.12.x
#
# Run from the folder containing the files:  sh install.sh
# After an OpenWrt update, run it again - labels in /etc/config/port_labels
# survive (config retention), only the app files need reinstalling.

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Port Labels installation ==="

# 1. CGI backend (pure shell/awk - no python required)
echo "[1/5] Installing CGI backend..."
mkdir -p /www/cgi-bin
cp "$SCRIPT_DIR/port-labels.sh" /www/cgi-bin/port-labels.sh
chmod 755 /www/cgi-bin/port-labels.sh

# 2. Status include + rpcd ACL
echo "[2/5] Installing LuCI include and ACL..."
mkdir -p /www/luci-static/resources/view/status/include /usr/share/rpcd/acl.d
cp "$SCRIPT_DIR/99_portlabels.js" /www/luci-static/resources/view/status/include/99_portlabels.js
cp "$SCRIPT_DIR/port_labels.json" /usr/share/rpcd/acl.d/port_labels.json

# 3. Patch 29_ports.js (device-specific: patch the file that is ON THIS box,
#    never copy one from another device - the file differs between LuCI
#    versions, and even between two boxes on the same release).
echo "[3/5] Patching 29_ports.js..."
TARGET=/www/luci-static/resources/view/status/include/29_ports.js
if grep -q pl-wrap "$TARGET"; then
    echo "  already patched"
elif command -v python3 >/dev/null 2>&1; then
    python3 "$SCRIPT_DIR/patch_29ports.py" "$TARGET"
else
    # python3 is absent on 25.12 by default - patch with awk using a LITERAL
    # (regex-free) index()/substr() replace so the JS payload needs no escaping.
    cp "$TARGET" "$TARGET.orig"
    awk -v snfile="$SCRIPT_DIR/badge_snippet.js" '
        BEGIN {
            old = "E(\047div\047,{\047class\047:\047ifacebox-body\047},[E(\047div\047,{\047class\047:\047cbi-tooltip-container\047";
            while ((getline l < snfile) > 0) sn = sn l;
        }
        { buf = buf $0 ORS }
        END {
            p = index(buf, old);
            if (p == 0) { print "NO_ANCHOR" > "/dev/stderr"; exit 1 }
            printf "%s%s%s", substr(buf,1,p-1), sn, substr(buf,p+length(old));
        }
    ' "$TARGET.orig" > "$TARGET" || {
        echo "  ERROR: awk patch failed - install python3-light and rerun:"
        echo "         opkg update && opkg install python3-light"
        cp "$TARGET.orig" "$TARGET"; exit 1
    }
    grep -q pl-wrap "$TARGET" || { echo "  ERROR: patch produced no badge"; cp "$TARGET.orig" "$TARGET"; exit 1; }
fi

# 4. UCI config (only if absent - existing labels are preserved)
echo "[4/5] Ensuring UCI config..."
if [ ! -s /etc/config/port_labels ]; then
    {
        echo "config port_labels 'settings'"
        echo "	option version '1'"
        i=1
        while [ $i -le 52 ]; do
            [ -e "/sys/class/net/lan$i" ] && { echo ""; echo "config label"; echo "	option port 'lan$i'"; }
            i=$((i+1))
        done
    } > /etc/config/port_labels
    echo "  created /etc/config/port_labels"
else
    echo "  kept existing /etc/config/port_labels"
fi

# 5. Clear LuCI cache and restart uhttpd
echo "[5/5] Restarting services..."
rm -f /tmp/luci-indexcache.*.json 2>/dev/null || true
/etc/init.d/uhttpd restart

echo ""
echo "=== Done ==="
echo "Open LuCI > Status > Overview and press Ctrl+Shift+R."
echo "Click a blue 'Label...' badge below a port tile to name it."
