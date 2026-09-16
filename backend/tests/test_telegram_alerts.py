from app.services.telegram_alerts import TelegramAlerts


def test_telegram_status_safe_without_credentials():
    t = TelegramAlerts()
    s = t.status()
    assert "configured" in s and "polling" in s
    assert "active_commands" in s


def test_option_formatter_helpers_import():
    from app.services.telegram_alerts import _fmt

    assert _fmt(123.456) == "123.46"
    assert _fmt(None) == "--"


def test_telegram_small_button_menu_contains_controls():
    t = TelegramAlerts()
    rows = t._menu_markup()["keyboard"]
    flat = [x for row in rows for x in row]
    assert "📊 NIFTY" in flat
    assert "🔍 SCAN A" in flat
    assert "⛔ STOP SCAN" in flat
    assert "⚡ GAMMA ON" in flat
    assert "⚡ GAMMA OFF" in flat
    assert "💰 PREMIUM" in flat


def test_index_pair_resolution():
    t = TelegramAlerts()
    assert t._pairs("nifty")[0][0] == "NIFTY"
    assert t._pairs("banknifty")[0][0] == "BANKNIFTY"
    assert t._pairs("sensex")[0][0] == "SENSEX"
