from pathlib import Path
from app.services.lifecycle import SignalLifecycle


def test_signal_trade_metadata_and_generated_time_persist(tmp_path: Path):
    db = tmp_path / 'signals.sqlite3'
    life = SignalLifecycle(db)
    row = life.create(
        symbol_key='nse_cm|RELIANCE', side='BUY', entry=100, stop=99,
        target1=101.85, target2=102.5, score=91, rr=1.85,
        trading_symbol='RELIANCE-EQ', exchange_segment='nse_cm',
        instrument_token='2885', generated_candle_at=1234567890,
    )
    assert row['trading_symbol'] == 'RELIANCE-EQ'
    again = SignalLifecycle(db).list(1)[0]
    assert again['trading_symbol'] == 'RELIANCE-EQ'
    assert again['exchange_segment'] == 'nse_cm'
    assert again['instrument_token'] == '2885'
    assert again['generated_candle_at'] == 1234567890
