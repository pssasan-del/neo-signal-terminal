from pathlib import Path
from app.services.lifecycle import SignalLifecycle


def test_signal_lifecycle_persists(tmp_path: Path):
    db = tmp_path / 'signals.sqlite3'
    a = SignalLifecycle(db)
    created = a.create(symbol_key='nse_cm|TEST', side='BUY', entry=100, stop=99, target1=102, target2=103, score=80, rr=2.0)
    a.update_price(created['id'], 102.5)
    b = SignalLifecycle(db)
    rows = b.list()
    assert rows and rows[0]['id'] == created['id']
    assert rows[0]['state'] == 'T1'


def test_signal_stats_survive_reload(tmp_path: Path):
    db = tmp_path / 'signals.sqlite3'
    a = SignalLifecycle(db)
    s = a.create(symbol_key='nse_cm|TEST', side='SELL', entry=100, stop=101, target1=98, target2=97, score=90, rr=2.0)
    a.update_price(s['id'], 97)
    b = SignalLifecycle(db)
    st = b.stats()
    assert st['total'] == 1 and st['wins'] == 1 and st['live'] == 0
