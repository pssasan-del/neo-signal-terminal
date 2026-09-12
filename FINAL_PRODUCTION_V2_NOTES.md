# KING BRO TRADE — Production V2 notes

- Live-order server gate defaults ON in source (`LIVE_ORDER_SUBMISSION_ENABLED=true` equivalent).
- Real order still requires authenticated Kotak session + Risk Gate ON + Execution ARMED + confirmation token.
- Option ranking now requires live LTP, acceptable spread, positive OI and usable Greeks.
- Broker Greeks/IV are preferred. If absent, IV and Delta/Gamma/Theta/Vega are computed from live premium using Black-Scholes and labelled `computed_black_scholes`.
- OI change is captured when broker payload supplies it.
- Missing OI/Greeks makes the option candidate non-tradable instead of fabricating values.
- Deploy must preserve `.env`, candle DB and signal lifecycle DB.
