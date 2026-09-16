from app.services.telegram_alerts import TelegramAlerts


def test_telegram_status_safe_without_credentials():
    t=TelegramAlerts()
    s=t.status()
    assert "configured" in s and "polling" in s


def test_option_formatter_helpers_import():
    from app.services.telegram_alerts import _fmt
    assert _fmt(123.456)=="123.46"
    assert _fmt(None)=="--"
