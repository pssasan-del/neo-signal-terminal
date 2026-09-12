from pathlib import Path
from tempfile import TemporaryDirectory

from app.services.lifecycle import SignalLifecycle, SignalState
from app.services.options import OptionSelector


def test_index_signal_without_contract_is_watching_not_trade_ready():
    with TemporaryDirectory() as td:
        lc = SignalLifecycle(Path(td) / 'signals.sqlite3')
        row = lc.create(
            symbol_key='nse_cm|Nifty 50', side='BUY', entry=25000, stop=24950,
            target1=25092.5, target2=25115, requires_tradable_contract=True,
            trade_ready=False, option_status='OPTION_DATA_UNAVAILABLE', option_type='CE'
        )
        assert row['trade_ready'] is False
        assert row['state'] == SignalState.WATCHING.value
        assert row['option_status'] == 'OPTION_DATA_UNAVAILABLE'


def test_option_normalization_keeps_lot_size_and_quality_fields():
    sel = OptionSelector(require_oi=True, require_greeks=False)
    c = sel.normalize({
        'instrument_token':'123', 'trading_symbol':'NIFTY25SEP25000CE',
        'strike_price':25000, 'option_type':'CE', 'exchange_segment':'NSEFO',
        'expiry':'25-09-2026', 'last_traded_price':120, 'best_bid_price':119.5,
        'best_ask_price':120.5, 'open_interest':100000, 'volume_traded_today':50000,
        'lot_size':75,
    })
    assert c is not None
    assert c.lot_size == 75
    assert c.trading_symbol == 'NIFTY25SEP25000CE'
