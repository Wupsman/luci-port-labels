#!/usr/bin/env python3
# patch_29ports.py
# Inserts a clickable "Label..." badge into the LuCI port-status view.
# Run locally against a copy of the target 29_ports.js, or on the router:
#   python3 patch_29ports.py
#
# NOTE: The badge is inserted BEFORE the ifacebox-body div, so it renders
# above the traffic counters (same position as the reference switch).

import sys
import os

TARGET = '/www/luci-static/resources/view/status/include/29_ports.js'
BACKUP = TARGET + '.orig'

if len(sys.argv) > 1:
    TARGET = sys.argv[1]
    BACKUP = TARGET + '.orig'

if not os.path.exists(TARGET):
    print('ERROR: file not found:', TARGET)
    sys.exit(1)

content = open(TARGET, encoding='utf-8').read()

if 'pl-wrap' in content:
    print('Already patched - nothing to do.')
    sys.exit(0)

old = "E('div',{'class':'ifacebox-body'},[E('div',{'class':'cbi-tooltip-container'"

# The trailing ")]),' closes the pl-label span, the pl-wrap div and its
# child array, then a comma continues the parent argument list. Getting
# this bracketing wrong produces a "missing ) after argument list" error.
new = ("E('div',{'class':'pl-wrap','style':'text-align:center;margin-top:3px'},"
       "[E('span',{'class':'pl-label','style':'font-size:10px;background:#1a3a6a;"
       "color:#8abcff;padding:1px 5px;border-radius:3px;cursor:pointer;display:inline-block',"
       "'click':function(ev){"
       "var el=ev.target.closest('.ifacebox');"
       "var pn=el.querySelector('.ifacebox-head').textContent.trim();"
       "var cur=(window._plLabels&&window._plLabels[pn])||'';"
       "var t=prompt('Label for '+pn+':',cur);"
       "if(t!=null){"
       "if(!window._plLabels)window._plLabels={};"
       "window._plLabels[pn]=t;"
       "ev.target.textContent=t||'Label...';"
       "fetch('/cgi-bin/port-labels.sh',{method:'POST',"
       "headers:{'Content-Type':'application/json'},"
       "body:JSON.stringify({port:pn,text:t})});}"
       "}},((window._plLabels&&window._plLabels[port.netdev.getName()])||'Label...'))]),"
       "E('div',{'class':'ifacebox-body'},[E('div',{'class':'cbi-tooltip-container'")

count = content.count(old)
if count != 1:
    print('ERROR: anchor found', count, 'times (expected 1)')
    sys.exit(1)

open(BACKUP, 'w', encoding='utf-8').write(content)
print('Backup written:', BACKUP)
open(TARGET, 'w', encoding='utf-8').write(content.replace(old, new))
print('Patch applied successfully.')
