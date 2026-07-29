#!/bin/bash
# calendar.sh — Month-calendar popup for the Polybar date module (click-right).

cal_html=$(cal | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
notify-send -i x-office-calendar "$(date '+%A, %B %d, %Y')" "<tt>${cal_html}</tt>" 2>/dev/null || true
