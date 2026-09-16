from pathlib import Path
from tempfile import TemporaryDirectory

from app.services.explosion_detector import ExplosionDetector


def _rows(n: int, start: float = 100.0, step: float = 1.0, volume: float = 100.0):
    rows = []
    px = start
    for i in range(n):
        o = px
        c = px + step
        rows.append({
            'open': o,
            'high': max(o, c) + 0.2,
            'low': min(o, c) - 0.2,
            'close': c,
            'volume': volume,
        })
        px = c
    return rows


def test_explosion_detector_is_independent_and_persists_toggle():
    with TemporaryDirectory() as td:
        db = Path(td) / 'explosion.sqlite3'
        d = ExplosionDetector(db)
        assert d.status()['enabled'] is False
        d.set_enabled(True)
        assert d.status()['enabled'] is True
        d2 = ExplosionDetector(db)
        assert d2.status()['enabled'] is True
        assert d2.status()['auto_execution'] is False
        assert d2.status()['mode'] == 'ALERT_ONLY'


def test_explosion_detector_scores_real_option_fields_and_saves_snapshot():
    with TemporaryDirectory() as td:
        d = ExplosionDetector(Path(td) / 'explosion.sqlite3')
        d.set_enabled(True)
        one = _rows(30, start=100, step=.6, volume=100)
        # Make the latest 1m candle a true structure/range/volume expansion.
        prior_high = max(x['high'] for x in one[-21:-1])
        one[-1] = {
            'open': prior_high - .3,
            'high': prior_high + 2.7,
            'low': prior_high - .4,
            'close': prior_high + 2.3,
            'volume': 260,
        }
        five = _rows(25, start=90, step=1.0, volume=100)
        fifteen = _rows(25, start=80, step=1.2, volume=100)
        base = d.evaluate_underlying('nse_cm|Nifty 50', one, five, fifteen, vix=12.5)
        assert base['side'] == 'BUY'
        assert base['score'] >= 55
        result = d.finalize_with_option(base, {
            'status': 'READY',
            'expiry': '17-09-2026',
            'selected': {
                'trading_symbol': 'NIFTY17SEP120CE',
                'instrument_token': '12345',
                'exchange_segment': 'nse_fo',
                'option_type': 'CE',
                'strike': 120,
                'expiry': '17-09-2026',
                'ltp': 25.0,
                'bid': 24.8,
                'ask': 25.2,
                'volume': 50000,
                'oi': 100000,
                'oi_change': 5000,
                'iv': .22,
                'delta': .55,
                'gamma': .018,
                'theta': -2.0,
                'vega': 1.2,
                'greeks_source': 'broker',
                'score': 94,
            },
        })
        assert result['state'] in {'TRIGGERED', 'EXPLOSION', 'RE-EXPLOSION'}
        assert result['option']['gamma'] == .018
        assert result['option']['oi_change'] == 5000
        hist = d.history(limit=5)
        assert len(hist) == 1
        assert hist[0]['option']['trading_symbol'] == 'NIFTY17SEP120CE'


def test_index_option_chain_returns_real_ce_pe_rows_without_fabrication():
    import asyncio
    import sys
    import types

    if 'neo_api_client' not in sys.modules:
        neo = types.ModuleType('neo_api_client')
        neo.NeoAPI = object
        websocket = types.ModuleType('neo_api_client.websocket')
        feed = types.ModuleType('neo_api_client.websocket.feed')
        feed.WsToken = object
        sys.modules['neo_api_client'] = neo
        sys.modules['neo_api_client.websocket'] = websocket
        sys.modules['neo_api_client.websocket.feed'] = feed

    from app.services.instruments import InstrumentResolver
    from app.services.broker import broker

    async def run():
        resolver = InstrumentResolver(ttl_sec=1)
        records = []
        for strike in (23050, 23100, 23150, 23200, 23250):
            for typ in ('CE', 'PE'):
                token = f'{strike}{typ}'
                records.append({
                    'instrument_token': token,
                    'trading_symbol': f'NIFTY17SEP{strike}{typ}',
                    'strike_price': strike,
                    'option_type': typ,
                    'exchange_segment': 'nse_fo',
                    'expiry': '17-09-2026',
                    'lot_size': 75,
                })

        async def fake_search(exchange_segment, symbol, expiry=None, option_type=None,
                              strike_price=None, ignore_50multiple=False):
            return {'data': records}

        async def fake_quote(exchange_segment, token, quote_type='all'):
            strike = int(token[:-2])
            typ = token[-2:]
            premium = max(8.0, 120.0 - abs(strike - 23100) * .8)
            return {'data': [{
                'instrument_token': token,
                'last_traded_price': premium,
                'best_bid_price': premium - .2,
                'best_ask_price': premium + .2,
                'open_interest': 100000,
                'volume_traded_today': 50000,
                'option_type': typ,
                'strike_price': strike,
                'expiry': '17-09-2026',
                'trading_symbol': f'NIFTY17SEP{strike}{typ}',
                'exchange_segment': exchange_segment,
            }]}

        old_quote = broker.quote
        old_tick = dict(broker.latest_ticks)
        try:
            resolver.search = fake_search
            broker.quote = fake_quote
            broker.latest_ticks['nse_cm|Nifty 50'] = {'last_traded_price': 23118.0}
            result = await resolver.index_option_chain(symbol_key='nse_cm|Nifty 50', strikes_each_side=1)
            assert result['status'] == 'READY'
            assert result['atm'] == 23100
            assert result['underlying_ltp'] == 23118.0
            assert len(result['rows']) == 6
            assert {x['option_type'] for x in result['rows']} == {'CE', 'PE'}
            assert all(x['trading_symbol'].startswith('NIFTY17SEP') for x in result['rows'])
            assert all(x['ltp'] is not None for x in result['rows'])
        finally:
            broker.quote = old_quote
            broker.latest_ticks.clear()
            broker.latest_ticks.update(old_tick)

    asyncio.run(run())
