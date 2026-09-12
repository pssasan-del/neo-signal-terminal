# V12 Signals 404 Fix

- Added `/signals/stats` backend endpoint.
- Added lifecycle stats implementation for older Oracle backend compatibility.
- Signals mobile page no longer fails entirely when only `/signals/stats` is missing.
- Mobile computes local stats from `/signals/lifecycle` as fallback.
- Raw HTTP 404 is no longer shown to the user.
