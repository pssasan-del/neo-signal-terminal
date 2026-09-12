# LION BRO final repair

Source base: user-uploaded `neo-signal-terminal-main.zip`.

Fixed:
- Android launcher label: `LION BRO` (removed `King Bro Trade`).
- Launcher icon: locked roaring-lion LION BRO emblem for legacy + adaptive Android launchers.
- Home indices: parses backend `indices` LIST and nested `tick.last_traded_price`.
- Watchlist: parses Kotak tick `last_traded_price` instead of showing `--`.
- Scanner: raw backend JSON removed; replaced by running status, resolved/configured/failed metrics and compact instrument list.
- Portfolio: robust nested holdings/limits parsing; supports `PREV CLOSE` label when backend provides fallback.
- Live Options: removed developer/debug copy and improved genuine-contract empty state.
- Manual Trade: extra top spacing and preserved two-step execution intent -> explicit confirmation safety.
- Strategy and backend option parser were not redesigned.
