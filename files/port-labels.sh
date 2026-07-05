#!/bin/sh
# Port-Labels CGI - reine Shell/awk-Variante (kein python3 noetig)
# GET:  {"lan1":"Router","lan4":"SofaSolar",...}
# POST: {"port":"lan1","text":"Neues Label"} -> {"result":"ok"}
echo "Content-Type: application/json"
echo "Access-Control-Allow-Origin: *"
echo ""

if [ "$REQUEST_METHOD" = "POST" ]; then
    BODY=$(cat)
    port=$(printf '%s' "$BODY" | jsonfilter -e '@.port' 2>/dev/null)
    text=$(printf '%s' "$BODY" | jsonfilter -e '@.text' 2>/dev/null)
    if [ -z "$port" ]; then
        echo '{"error":"port missing"}'
        exit 0
    fi
    section=$(uci show port_labels 2>/dev/null | sed -n "s/^port_labels\.\([^.]*\)\.port='$port'\$/\1/p" | head -n 1)
    if [ -n "$section" ]; then
        uci set "port_labels.$section.text=$text" && uci commit port_labels
        echo '{"result":"ok"}'
    else
        echo '{"error":"port not found"}'
    fi
else
    uci show port_labels 2>/dev/null | awk -F"='" '
        BEGIN { printf "{\"labels\":{" ; sep="" }
        /\.port=/ { p=$2; sub(/\x27$/,"",p); port=p }
        /\.text=/ {
            v=$2; sub(/\x27$/,"",v)
            gsub(/\\/,"\\\\",v); gsub(/"/,"\\\"",v)
            if (port != "") { printf "%s\"%s\":\"%s\"", sep, port, v; sep="," }
        }
        END { print "}}" }'
fi
