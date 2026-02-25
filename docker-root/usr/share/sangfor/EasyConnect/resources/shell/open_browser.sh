#!/bin/bash
set -u

url="$2"
printf '%s\n' "$url" >> /root/open-urls

(
	[ -n "${URLWIN:-}" ] && xmessage -buttons Copy:0,Close:1 "$url" && ( printf %s "$url" | xclip -i -selection clipboard )
)&

if [ -n "${CHROMIUM:-}" ]; then
	case "$url" in
		http://*|https://*)
			if command -v chromium-launcher >/dev/null 2>&1; then
				chromium-launcher "$url" >/dev/null 2>&1 &
			elif command -v chromium >/dev/null 2>&1; then
				chromium --no-sandbox --disable-gpu --disable-dev-shm-usage "$url" >/dev/null 2>&1 &
			elif command -v chromium-browser >/dev/null 2>&1; then
				chromium-browser --no-sandbox --disable-gpu --disable-dev-shm-usage "$url" >/dev/null 2>&1 &
			fi
			exit 0
			;;
	esac
fi
