import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'backend_config.dart';

void main() => runApp(const LionBroApp());

class C {
  static const bg = Color(0xFF060A0E);
  static const panel = Color(0xFF0D141B);
  static const panel2 = Color(0xFF141C24);
  static const border = Color(0xFF26323D);
  static const red = Color(0xFFF10F36);
  static const green = Color(0xFF16D58B);
  static const text = Color(0xFFF5F7F9);
  static const muted = Color(0xFF91A0AD);
  static const whiteCard = Color(0xFFF8FAFB);
}

class LionBroApp extends StatefulWidget {
  const LionBroApp({super.key});
  @override
  State<LionBroApp> createState() => _LionBroAppState();
}

class _LionBroAppState extends State<LionBroApp> {
  String? baseUrl;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final v = await BackendConfig.loadBaseUrl();
    if (mounted) setState(() => baseUrl = v);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LION BRO',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: C.bg,
        colorScheme: const ColorScheme.dark(primary: C.red, secondary: C.green),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: baseUrl == null
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator(color: C.red)))
          : SplashPage(baseUrl: baseUrl!),
    );
  }
}

class SplashPage extends StatefulWidget {
  const SplashPage({super.key, required this.baseUrl});
  final String baseUrl;
  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted)
        Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => LoginPage(baseUrl: widget.baseUrl)));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Expanded(
              child: Stack(fit: StackFit.expand, children: [
            Image.asset('assets/lion_bro_splash.png', fit: BoxFit.cover),
            const DecoratedBox(
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                  Colors.transparent,
                  Color(0x99060A0E),
                  C.bg
                ]))),
          ])),
          const SizedBox(height: 12),
          const BrandTitle(size: 32),
          const SizedBox(height: 6),
          const Text('TRADE SMART  •  TRADE BOLD',
              style: TextStyle(
                  letterSpacing: 2.2,
                  fontSize: 11,
                  color: C.muted,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 30),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 54),
              child: LinearProgressIndicator(
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(10),
                  color: C.red,
                  backgroundColor: C.panel2)),
          const SizedBox(height: 10),
          const Text('Loading markets…',
              style: TextStyle(color: C.muted, fontSize: 12)),
          const SizedBox(height: 30),
        ]),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.baseUrl});
  final String baseUrl;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final totp = TextEditingController();
  bool busy = false;
  String? error;
  late final ApiService api = ApiService(widget.baseUrl);
  @override
  void dispose() {
    totp.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final code = totp.text.trim();
    if (code.length < 6) {
      setState(() => error = 'Enter the current Kotak TOTP');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final r = await api.postJson('/auth/login', {'totp': code},
          timeout: const Duration(seconds: 25));
      if (!mounted) return;
      if (r['ok'] == true) {
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => AppShell(baseUrl: widget.baseUrl)));
      } else {
        setState(() => error =
            'Login failed: ${r['detail'] ?? r['message'] ?? 'Unknown response'}');
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: SafeArea(
            child: Center(
                child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(children: [
                          ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Image.asset('assets/lion_bro_logo.png',
                                  height: 150, width: 150, fit: BoxFit.cover)),
                          const SizedBox(height: 10),
                          const BrandTitle(size: 30),
                          const SizedBox(height: 5),
                          const Text('TRADE SMART  •  TRADE BOLD',
                              style: TextStyle(
                                  color: C.muted,
                                  letterSpacing: 1.6,
                                  fontSize: 10)),
                          const SizedBox(height: 28),
                          Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                  color: C.panel,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: C.border)),
                              child: const Row(children: [
                                Icon(Icons.verified_user_outlined,
                                    color: C.green),
                                SizedBox(width: 10),
                                Expanded(
                                    child: Text(
                                        'Kotak credentials stay on the backend. Enter only the current TOTP here.',
                                        style: TextStyle(
                                            color: C.muted, fontSize: 12)))
                              ])),
                          const SizedBox(height: 12),
                          TextField(
                              controller: totp,
                              keyboardType: TextInputType.number,
                              obscureText: true,
                              maxLength: 8,
                              decoration: InputDecoration(
                                  counterText: '',
                                  prefixIcon: const Icon(Icons.pin_outlined,
                                      color: C.muted),
                                  hintText: 'Kotak TOTP',
                                  filled: true,
                                  fillColor: C.panel2,
                                  border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)))),
                          if (error != null)
                            Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Text(error!,
                                    style: const TextStyle(color: C.red))),
                          const SizedBox(height: 14),
                          SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: FilledButton(
                                  style: FilledButton.styleFrom(
                                      backgroundColor: C.red,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12))),
                                  onPressed: busy ? null : _login,
                                  child: busy
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white))
                                      : const Text('Login to LION BRO',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w800)))),
                          const SizedBox(height: 14),
                          Text(widget.baseUrl,
                              style: const TextStyle(
                                  color: C.muted, fontSize: 10)),
                        ]))))));
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.baseUrl});
  final String baseUrl;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int tab = 0;
  late final ApiService api = ApiService(widget.baseUrl);
  StreamSubscription? ticks;
  bool ws = false;
  @override
  void initState() {
    super.initState();
    ticks = api.reconnectingTicks().listen((e) {
      if (!mounted) return;
      final c = e['_connection'];
      if (c == 'connected' && !ws) setState(() => ws = true);
      if (c == 'disconnected' && ws) setState(() => ws = false);
    });
  }

  @override
  void dispose() {
    ticks?.cancel();
    super.dispose();
  }

  Future<void> _logout() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: C.panel,
        title: const Text('Logout from LION BRO?'),
        content: const Text(
            'This will close the current Kotak broker session and return to login.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Logout')),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await api.postJson('/auth/logout', const <String, dynamic>{});
    } catch (_) {}
    if (!mounted) return;
    await ticks?.cancel();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => LoginPage(baseUrl: widget.baseUrl)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      LiveHomePage(api: api, ws: ws, onLogout: _logout),
      LiveWatchlistPage(api: api),
      LiveTradePage(api: api),
      LiveOrdersPage(api: api),
      LivePortfolioPage(api: api)
    ];
    return Scaffold(
        body: SafeArea(child: pages[tab]),
        bottomNavigationBar: NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (i) => setState(() => tab = i),
            backgroundColor: const Color(0xFF0A1016),
            indicatorColor: const Color(0x33F10F36),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home, color: C.red),
                  label: 'Home'),
              NavigationDestination(
                  icon: Icon(Icons.star_border),
                  selectedIcon: Icon(Icons.star, color: C.red),
                  label: 'Watchlist'),
              NavigationDestination(
                  icon: Icon(Icons.swap_vert),
                  selectedIcon: Icon(Icons.swap_vert, color: C.red),
                  label: 'Trade'),
              NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long, color: C.red),
                  label: 'Orders'),
              NavigationDestination(
                  icon: Icon(Icons.account_balance_wallet_outlined),
                  selectedIcon:
                      Icon(Icons.account_balance_wallet, color: C.red),
                  label: 'Portfolio'),
            ]));
  }
}

class AppHeader extends StatelessWidget {
  final String? title;
  final bool back;
  final List<Widget>? actions;
  const AppHeader({super.key, this.title, this.back = false, this.actions});
  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Row(children: [
          if (back)
            IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new, size: 20)),
          if (title == null) ...[
            ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Image.asset('assets/lion_bro_logo.png',
                    width: 34, height: 34, fit: BoxFit.cover)),
            const SizedBox(width: 9),
            const BrandTitle(size: 20)
          ] else
            Expanded(
                child: Text(title!,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w900))),
          if (title == null) const Spacer(),
          ...?actions,
        ]));
  }
}

class BrandTitle extends StatelessWidget {
  final double size;
  const BrandTitle({super.key, this.size = 24});
  @override
  Widget build(BuildContext context) => RichText(
          text: TextSpan(
              style: TextStyle(
                  fontSize: size,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .4),
              children: const [
            TextSpan(text: 'LION ', style: TextStyle(color: Colors.white)),
            TextSpan(text: 'BRO', style: TextStyle(color: C.red))
          ]));
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    return ListView(padding: EdgeInsets.zero, children: [
      AppHeader(actions: [
        _StatusPill(text: 'Market Open', color: C.green),
        IconButton(onPressed: () {}, icon: const Icon(Icons.search)),
        IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none))
      ]),
      const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Expanded(
                child: _IndexCard('NIFTY', '24,198.50', '+182.60', '+0.76%')),
            SizedBox(width: 8),
            Expanded(
                child:
                    _IndexCard('BANKNIFTY', '51,230.10', '+412.30', '+0.81%')),
            SizedBox(width: 8),
            Expanded(
                child: _IndexCard('SENSEX', '79,412.25', '+612.55', '+0.78%'))
          ])),
      const SizedBox(height: 12),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: C.whiteCard, borderRadius: BorderRadius.circular(18)),
              child: Row(children: [
                const Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Portfolio Value',
                          style:
                              TextStyle(color: Colors.black54, fontSize: 12)),
                      SizedBox(height: 4),
                      Text('₹ 5,24,300',
                          style: TextStyle(
                              color: Colors.black,
                              fontSize: 25,
                              fontWeight: FontWeight.w900)),
                      SizedBox(height: 6),
                      Text('Day P&L  +₹8,245  (+1.60%)',
                          style: TextStyle(
                              color: Color(0xFF009E65),
                              fontWeight: FontWeight.w800))
                    ])),
                SizedBox(
                    width: 105,
                    height: 62,
                    child: CustomPaint(painter: LineChartPainter()))
              ]))),
      const SizedBox(height: 14),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _Quick(
                icon: Icons.swap_horiz,
                label: 'Trade',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const TradePage()))),
            _Quick(
                icon: Icons.table_chart_outlined,
                label: 'Option Chain',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const OptionChainPage()))),
            _Quick(
                icon: Icons.radar,
                label: 'Signals',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SignalsPage()))),
            _Quick(
                icon: Icons.manage_search,
                label: 'Scanner',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ScannerPage()))),
          ])),
      const SizedBox(height: 16),
      const _SectionTitle('Latest Signal'),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                  color: C.whiteCard, borderRadius: BorderRadius.circular(16)),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const _Tag('BUY', C.green),
                const SizedBox(width: 12),
                const Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('NIFTY 24500 CE',
                          style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w900,
                              fontSize: 16)),
                      SizedBox(height: 5),
                      Text('Entry: 124.50   SL: 92.00',
                          style: TextStyle(color: Colors.black54)),
                      Text('Targets: 160 / 210',
                          style: TextStyle(color: Colors.black54)),
                      SizedBox(height: 5),
                      Text('Strong OI + RSI Up',
                          style: TextStyle(
                              color: Color(0xFF009E65),
                              fontWeight: FontWeight.w700))
                    ])),
                TextButton(onPressed: () {}, child: const Text('Details'))
              ]))),
      const SizedBox(height: 18),
    ]);
  }
}

class WatchlistPage extends StatelessWidget {
  const WatchlistPage({super.key});
  static const rows = [
    ['RELIANCE', '2,956.40', '+24.60', '+0.84%'],
    ['HDFCBANK', '1,678.90', '+12.35', '+0.74%'],
    ['ICICIBANK', '1,120.50', '-3.20', '-0.28%'],
    ['INFY', '1,530.25', '+8.75', '+0.57%'],
    ['TCS', '3,985.60', '+22.40', '+0.57%'],
    ['SBIN', '758.20', '+5.35', '+0.71%'],
    ['ONGC', '247.80', '-1.10', '-0.44%'],
    ['NIFTY', '24,198.50', '+182.60', '+0.76%'],
    ['BANKNIFTY', '51,230.10', '+412.30', '+0.81%']
  ];
  @override
  Widget build(BuildContext context) => Column(children: [
        const AppHeader(title: 'Watchlist', actions: [
          Icon(Icons.search),
          SizedBox(width: 12),
          Icon(Icons.notifications_none)
        ]),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              const _TabChip('My List 1', true),
              const _TabChip('F&O', false),
              const _TabChip('Banking', false),
              const Spacer(),
              IconButton(onPressed: () {}, icon: const Icon(Icons.add))
            ])),
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
                decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Search stock, index, or symbol…',
                    filled: true,
                    fillColor: C.panel,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: C.border))))),
        const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(
                  flex: 3,
                  child: Text('Symbol',
                      style: TextStyle(color: C.muted, fontSize: 11))),
              Expanded(
                  child: Text('LTP',
                      textAlign: TextAlign.right,
                      style: TextStyle(color: C.muted, fontSize: 11))),
              Expanded(
                  child: Text('Chg',
                      textAlign: TextAlign.right,
                      style: TextStyle(color: C.muted, fontSize: 11))),
              Expanded(
                  child: Text('%',
                      textAlign: TextAlign.right,
                      style: TextStyle(color: C.muted, fontSize: 11)))
            ])),
        Expanded(
            child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: rows.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: C.border),
                itemBuilder: (context, i) {
                  final r = rows[i];
                  final up = !r[2].startsWith('-');
                  return InkWell(
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  StockPage(symbol: r[0], price: r[1]))),
                      child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          child: Row(children: [
                            Expanded(
                                flex: 3,
                                child: Text(r[0],
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800))),
                            Expanded(
                                child: Text(r[1], textAlign: TextAlign.right)),
                            Expanded(
                                child: Text(r[2],
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                        color: up ? C.green : C.red,
                                        fontWeight: FontWeight.w700))),
                            Expanded(
                                child: Text(r[3],
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                        color: up ? C.green : C.red,
                                        fontWeight: FontWeight.w700)))
                          ])));
                }))
      ]);
}

class StockPage extends StatelessWidget {
  final String symbol, price;
  const StockPage({super.key, required this.symbol, required this.price});
  @override
  Widget build(BuildContext context) => Scaffold(
          body: SafeArea(
              child: ListView(children: [
        AppHeader(
            title: symbol,
            back: true,
            actions: [_StatusPill(text: 'NSE', color: C.muted)]),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(price,
                  style: const TextStyle(
                      fontSize: 30, fontWeight: FontWeight.w900)),
              const SizedBox(width: 10),
              const Padding(
                  padding: EdgeInsets.only(bottom: 5),
                  child: Text('+24.60 (+0.84%)',
                      style: TextStyle(
                          color: C.green, fontWeight: FontWeight.w800)))
            ])),
        const SizedBox(height: 10),
        const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              _TabChip('Chart', true),
              _TabChip('Overview', false),
              _TabChip('Depth', false),
              _TabChip('News', false)
            ])),
        const SizedBox(height: 12),
        const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              _MiniChip('1m'),
              _MiniChip('5m'),
              _MiniChip('15m', active: true),
              _MiniChip('1H'),
              _MiniChip('1D'),
              _MiniChip('1W')
            ])),
        Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
                height: 330,
                decoration: BoxDecoration(
                    color: C.panel,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: C.border)),
                child: CustomPaint(painter: CandlePainter()))),
        const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(child: _TradeButton('BUY', C.green)),
              SizedBox(width: 10),
              Expanded(child: _TradeButton('SELL', C.red))
            ])),
        const SizedBox(height: 18),
      ])));
}

class OptionChainPage extends StatelessWidget {
  const OptionChainPage({super.key});

  @override
  Widget build(BuildContext context) {
    final data = <List<String>>[
      ['124.50', '12,340', '24,000', '13,250', '98.10'],
      ['101.20', '15,880', '24,050', '16,420', '120.40'],
      ['82.60', '18,440', '24,100', '20,340', '145.30'],
      ['65.20', '24,510', '24,150', '22,880', '172.60'],
      ['52.40', '28,120', '24,200', '26,770', '206.15'],
      ['41.35', '32,440', '24,250', '30,880', '243.75'],
      ['32.10', '40,220', '24,300', '38,110', '282.40'],
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppHeader(
              title: 'NIFTY Option Chain',
              back: true,
              actions: [Icon(Icons.search)],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _TabChip('21 Nov', true),
                  _TabChip('28 Nov', false),
                  _TabChip('05 Dec', false),
                  _TabChip('12 Dec', false),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Text('Spot: 24,198.50',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  SizedBox(width: 8),
                  Text('+182.60 (+0.76%)',
                      style: TextStyle(
                          color: C.green, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                      child: Text('CALLS',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: C.green, fontWeight: FontWeight.w900))),
                  Expanded(
                      child: Text('PUTS',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: C.red, fontWeight: FontWeight.w900))),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: data.length,
                itemBuilder: (context, i) {
                  final r = data[i];
                  final atm = i == 3;
                  return Container(
                    color: atm ? const Color(0x2216D58B) : Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 13),
                    child: Row(
                      children: [
                        Expanded(
                            child: Text(r[0],
                                style: const TextStyle(
                                    color: C.green,
                                    fontWeight: FontWeight.w800))),
                        Expanded(
                            child: Text(r[1],
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: C.muted))),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            decoration: BoxDecoration(
                              color: atm ? C.whiteCard : C.panel2,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              r[2],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: atm ? Colors.black : C.text,
                                  fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                        Expanded(
                            child: Text(r[3],
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: C.muted))),
                        Expanded(
                            child: Text(r[4],
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    color: C.red,
                                    fontWeight: FontWeight.w800))),
                      ],
                    ),
                  );
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(child: _BottomAction('Chain', true)),
                  SizedBox(width: 8),
                  Expanded(child: _BottomAction('OI Analysis', false)),
                  SizedBox(width: 8),
                  Expanded(child: _BottomAction('Greeks', false)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TradePage extends StatefulWidget {
  const TradePage({super.key});
  @override
  State<TradePage> createState() => _TradePageState();
}

class _TradePageState extends State<TradePage> {
  int qty = 1;
  bool buy = true;
  String product = 'MIS';
  String order = 'Market';
  @override
  Widget build(BuildContext context) =>
      ListView(padding: EdgeInsets.zero, children: [
        const AppHeader(
            title: 'NIFTY 24500 CE',
            actions: [_StatusPill(text: 'NFO', color: C.muted)]),
        const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Text('126.40',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
              SizedBox(width: 9),
              Text('+18.30 (+16.92%)',
                  style: TextStyle(color: C.green, fontWeight: FontWeight.w800))
            ])),
        const SizedBox(height: 14),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(
                  child: ChoiceChip(
                      label: const Text('Buy'),
                      selected: buy,
                      selectedColor: C.red,
                      onSelected: (_) => setState(() => buy = true))),
              const SizedBox(width: 8),
              Expanded(
                  child: ChoiceChip(
                      label: const Text('Sell'),
                      selected: !buy,
                      selectedColor: C.red,
                      onSelected: (_) => setState(() => buy = false)))
            ])),
        const SizedBox(height: 18),
        const _FieldLabel('Quantity (Lots)'),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              IconButton.filledTonal(
                  onPressed: () => setState(() => qty = math.max(1, qty - 1)),
                  icon: const Icon(Icons.remove)),
              Expanded(
                  child: Center(
                      child: Text('$qty',
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w900)))),
              IconButton.filledTonal(
                  onPressed: () => setState(() => qty++),
                  icon: const Icon(Icons.add)),
              const SizedBox(width: 12),
              const Text('Lot size: 50', style: TextStyle(color: C.muted))
            ])),
        const SizedBox(height: 18),
        const _FieldLabel('Product'),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
                spacing: 8,
                children: ['MIS', 'NRML', 'CNC']
                    .map((e) => ChoiceChip(
                        label: Text(e),
                        selected: product == e,
                        selectedColor: C.red,
                        onSelected: (_) => setState(() => product = e)))
                    .toList())),
        const SizedBox(height: 18),
        const _FieldLabel('Order Type'),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
                spacing: 8,
                children: ['Market', 'Limit', 'SL', 'SL-M']
                    .map((e) => ChoiceChip(
                        label: Text(e),
                        selected: order == e,
                        selectedColor: C.red,
                        onSelected: (_) => setState(() => order = e)))
                    .toList())),
        const SizedBox(height: 18),
        const _FieldLabel('Price'),
        const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _DarkField(icon: Icons.currency_rupee, hint: '126.40')),
        const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text('Margin Required  ₹ 6,320 (Approx)',
                style: TextStyle(color: C.muted))),
        Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
                height: 56,
                child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: buy ? C.red : C.green,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                    onPressed: () => showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                                backgroundColor: C.panel,
                                title: Text(
                                    '${buy ? 'BUY' : 'SELL'} order preview'),
                                content: Text(
                                    'NIFTY 24500 CE\n$qty lot(s) • $product • $order\n\nPrototype only — no broker order is sent.'),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancel')),
                                  FilledButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Confirm'))
                                ])),
                    child: Text('Swipe to ${buy ? 'Buy' : 'Sell'}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 16))))),
      ]);
}

class SignalsPage extends StatelessWidget {
  const SignalsPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
          body: SafeArea(
              child: Column(children: [
        const AppHeader(
            title: 'LION BRO Signals',
            back: true,
            actions: [Icon(Icons.search)]),
        const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              _TabChip('All', true),
              _TabChip('NIFTY', false),
              _TabChip('BANKNIFTY', false),
              _TabChip('Stocks', false)
            ])),
        Expanded(
            child: ListView(padding: const EdgeInsets.all(16), children: const [
          _SignalCard('NIFTY 24500 CE', '10:12 AM', '124.50', '92.00',
              '160 / 210', 'Strong OI + RSI Up'),
          _SignalCard('BANKNIFTY 51200 PE', '09:40 AM', '168.30', '135.00',
              '210 / 280', 'OI Build-up'),
          _SignalCard('RELIANCE', '09:20 AM', '2,920.00', '2,860.00',
              '3,050 / 3,120', 'Breakout + Volume')
        ]))
      ])));
}

class ScannerPage extends StatelessWidget {
  const ScannerPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
          body: SafeArea(
              child: Column(children: [
        const AppHeader(title: 'Market Scanner', back: true),
        const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              _TabChip('Stocks', true),
              _TabChip('F&O', false),
              _TabChip('Strategies', false)
            ])),
        Expanded(
            child: ListView(padding: const EdgeInsets.all(16), children: const [
          _ScanRow(Icons.bubble_chart_outlined, 'High OI Build-up'),
          _ScanRow(Icons.trending_up, 'Price Breakout'),
          _ScanRow(Icons.speed, 'RSI Oversold'),
          _ScanRow(Icons.stacked_line_chart, 'Williams %R Reversal'),
          _ScanRow(Icons.grid_view, 'CPR Breakout'),
          _ScanRow(Icons.bar_chart, 'Volume Spike'),
          _ScanRow(Icons.show_chart, 'EMA Crossover'),
          _ScanRow(Icons.tune, 'Custom Scan')
        ])),
        Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: C.red),
                    onPressed: () {},
                    child: const Text('Run Scan',
                        style: TextStyle(fontWeight: FontWeight.w900)))))
      ])));
}

class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});
  @override
  Widget build(BuildContext context) => Column(children: [
        const AppHeader(title: 'Orders', actions: [Icon(Icons.search)]),
        const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              _TabChip('Pending', true),
              _TabChip('Executed', false),
              _TabChip('Rejected', false)
            ])),
        Expanded(
            child: ListView(padding: const EdgeInsets.all(16), children: const [
          _OrderCard('NIFTY 24500 CE', 'BUY', '50 / 50', '126.40', 'Completed',
              '10:15 AM'),
          _OrderCard('RELIANCE', 'SELL', '10 / 10', '3,025.00', 'Completed',
              '09:48 AM'),
          _OrderCard('BANKNIFTY 51200 PE', 'BUY', '25 / 25', '165.60',
              'Completed', '09:32 AM')
        ]))
      ]);
}

class PortfolioPage extends StatelessWidget {
  const PortfolioPage({super.key});
  @override
  Widget build(BuildContext context) =>
      ListView(padding: EdgeInsets.zero, children: [
        const AppHeader(title: 'Portfolio', actions: [Icon(Icons.search)]),
        const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              _TabChip('Positions', true),
              _TabChip('Holdings', false),
              _TabChip('Funds', false)
            ])),
        const SizedBox(height: 12),
        const _SectionTitle('Open Positions'),
        const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _WhiteInfoCard(children: [
              _PnlRow(
                  'NIFTY 24500 CE', 'Qty 50 • LTP 168.50', '+₹2,450.00', true),
              _PnlRow('BANKNIFTY 51200 PE', 'Qty 25 • LTP 155.60', '-₹1,120.00',
                  false),
              _PnlRow('RELIANCE', 'Qty 10 • LTP 3,025.00', '+₹850.00', true)
            ])),
        const SizedBox(height: 16),
        const _SectionTitle('Holdings'),
        const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _WhiteInfoCard(children: [
              _PnlRow('RELIANCE', 'Invested ₹1,20,000', '+₹22,450', true),
              _PnlRow('HDFCBANK', 'Invested ₹98,500', '+₹16,320', true),
              _PnlRow('TCS', 'Invested ₹75,200', '+₹12,650', true)
            ])),
        const SizedBox(height: 16),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: C.panel, borderRadius: BorderRadius.circular(16)),
                child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Available Cash', style: TextStyle(color: C.muted)),
                      SizedBox(height: 5),
                      Text('₹ 1,25,430',
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w900)),
                      SizedBox(height: 12),
                      Text('Used Margin  ₹ 83,220',
                          style: TextStyle(color: C.muted)),
                      Text('Total Limit  ₹ 2,50,000',
                          style: TextStyle(color: C.muted))
                    ]))),
        const SizedBox(height: 18),
      ]);
}

// ===== LIVE BACKEND CONNECTED PAGES =====
double _n(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse('${v ?? ''}'.replaceAll(',', '').trim()) ?? 0;
}

String _money(dynamic v) {
  if (v == null || '$v'.trim().isEmpty) return '--';
  final n = _n(v);
  return '₹${n.toStringAsFixed(2)}';
}

Map<String, dynamic> _m(dynamic v) => v is Map<String, dynamic>
    ? v
    : v is Map
        ? Map<String, dynamic>.from(v)
        : <String, dynamic>{};

List _l(dynamic v) => v is List ? v : <dynamic>[];

dynamic _pick(Map<String, dynamic> m, List<String> keys) {
  for (final key in keys) {
    final v = m[key];
    if (v != null && '$v'.trim().isNotEmpty) return v;
  }
  return null;
}

dynamic _deepPick(dynamic value, List<String> keys) {
  if (value is Map) {
    final m = Map<String, dynamic>.from(value);
    final direct = _pick(m, keys);
    if (direct != null) return direct;
    for (final v in m.values) {
      final found = _deepPick(v, keys);
      if (found != null) return found;
    }
  } else if (value is List) {
    for (final v in value) {
      final found = _deepPick(v, keys);
      if (found != null) return found;
    }
  }
  return null;
}

double _tickPrice(dynamic value) {
  final m = _m(value);
  return _n(_pick(m, const [
    'last_traded_price',
    'ltp',
    'last_price',
    'lastPrice',
    'price',
    'lastTradedPrice',
    'pLTP',
    'close_price',
    'closePrice'
  ]));
}

List _records(dynamic value, {List<String> preferredKeys = const []}) {
  if (value is List) return value;
  if (value is! Map) return const [];
  final m = Map<String, dynamic>.from(value);
  for (final key in [
    ...preferredKeys,
    'data',
    'rows',
    'items',
    'result',
    'results'
  ]) {
    final v = m[key];
    if (v is List) return v;
    if (v is Map) {
      final nested = _records(v, preferredKeys: preferredKeys);
      if (nested.isNotEmpty) return nested;
    }
  }
  return const [];
}

String _sym(dynamic value) {
  final m = _m(value);
  return '${_pick(m, const [
            'trading_symbol',
            'tradingSymbol',
            'symbol',
            'displayName',
            'symbol_key'
          ]) ?? '--'}';
}

class LiveHomePage extends StatefulWidget {
  const LiveHomePage(
      {super.key, required this.api, required this.ws, required this.onLogout});
  final ApiService api;
  final bool ws;
  final Future<void> Function() onLogout;
  @override
  State<LiveHomePage> createState() => _LiveHomePageState();
}

class _LiveHomePageState extends State<LiveHomePage> {
  Map<String, dynamic> b = {};
  String? err;
  Timer? timer;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _load();
    timer =
        Timer.periodic(const Duration(seconds: 5), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) setState(() => busy = true);
    try {
      final r = await widget.api.getJson('/app/bootstrap');
      if (mounted)
        setState(() {
          b = r;
          err = null;
        });
    } catch (e) {
      if (mounted) setState(() => err = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Map<String, dynamic> _indexRow(String name) {
    final raw = b['indices'];
    if (raw is List) {
      for (final x in raw) {
        final m = _m(x);
        final label = '${m['label'] ?? m['name'] ?? ''}'
            .toUpperCase()
            .replaceAll(' ', '');
        final wanted = name.toUpperCase().replaceAll(' ', '');
        if (label == wanted || label.contains(wanted) || wanted.contains(label))
          return m;
      }
    } else if (raw is Map) {
      final im = Map<String, dynamic>.from(raw);
      for (final e in im.entries) {
        if (e.key
            .toUpperCase()
            .replaceAll(' ', '')
            .contains(name.toUpperCase().replaceAll(' ', ''))) {
          return _m(e.value);
        }
      }
    }
    return {};
  }

  Widget _index(String name) {
    final row = _indexRow(name);
    final tick = _m(row['tick']);
    final p = _tickPrice(tick.isNotEmpty ? tick : row);
    final ch = _n(_pick(
        tick, const ['change', 'net_change', 'change_value', 'netChange']));
    final pc = _n(_pick(tick, const [
      'change_percent',
      'percent_change',
      'changePercentage',
      'per_change'
    ]));
    return _IndexCard(
      name,
      p <= 0 ? '--' : p.toStringAsFixed(2),
      ch == 0 ? '--' : '${ch >= 0 ? '+' : ''}${ch.toStringAsFixed(2)}',
      pc == 0 ? '--' : '${pc >= 0 ? '+' : ''}${pc.toStringAsFixed(2)}%',
    );
  }

  @override
  Widget build(BuildContext context) {
    final h = _m(b['health']);
    final ps = _m(b['position_summary']);
    final sig = _l(b['signals']);
    final latest = sig.isEmpty ? <String, dynamic>{} : _m(sig.first);
    final pnlRaw = _pick(ps, const ['day_mtm', 'day_pnl']);
    final pnl = _n(pnlRaw);
    final auth = h['authenticated'] == true;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          AppHeader(actions: [
            _StatusPill(
                text: auth ? (widget.ws ? 'LIVE' : 'API OK') : 'Login Required',
                color: auth ? C.green : C.red),
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
            PopupMenuButton<String>(
              tooltip: 'Account',
              icon: const Icon(Icons.account_circle_outlined),
              onSelected: (v) {
                if (v == 'logout') widget.onLogout();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                    value: 'logout',
                    child: Row(children: [
                      Icon(Icons.logout),
                      SizedBox(width: 10),
                      Text('Logout')
                    ]))
              ],
            ),
          ]),
          if (err != null)
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(err!,
                    style: const TextStyle(color: C.red, fontSize: 12))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(child: _index('NIFTY')),
              const SizedBox(width: 8),
              Expanded(child: _index('BANKNIFTY')),
              const SizedBox(width: 8),
              Expanded(child: _index('SENSEX')),
            ]),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: C.whiteCard, borderRadius: BorderRadius.circular(18)),
              child: Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const Text('Live Position P&L',
                          style:
                              TextStyle(color: Colors.black54, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(pnlRaw == null ? '--' : _money(pnl),
                          style: TextStyle(
                              color: pnl < 0 ? C.red : Colors.black,
                              fontSize: 25,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      Text('${ps['open_positions'] ?? 0} open position(s)',
                          style: TextStyle(
                              color: pnl < 0 ? C.red : const Color(0xFF009E65),
                              fontWeight: FontWeight.w800)),
                    ])),
                const SizedBox(
                    width: 105,
                    height: 62,
                    child: CustomPaint(painter: LineChartPainter())),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _Quick(
                      icon: Icons.swap_horiz,
                      label: 'Trade',
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => LiveTradePage(api: widget.api)))),
                  _Quick(
                      icon: Icons.table_chart_outlined,
                      label: 'Option Chain',
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  LiveOptionPage(api: widget.api)))),
                  _Quick(
                      icon: Icons.radar,
                      label: 'Signals',
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  LiveSignalsPage(api: widget.api)))),
                  _Quick(
                      icon: Icons.manage_search,
                      label: 'Scanner',
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  LiveScannerPage(api: widget.api)))),
                ]),
          ),
          const SizedBox(height: 16),
          const _SectionTitle('Latest Signal'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: latest.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                        color: C.panel,
                        borderRadius: BorderRadius.circular(16)),
                    child: const Text('No live signal yet.',
                        style: TextStyle(color: C.muted)))
                : _LiveSignalCard(latest),
          ),
          if (busy)
            const Padding(
                padding: EdgeInsets.all(12),
                child: LinearProgressIndicator(color: C.red)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

extension _FirstOrNullExt<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class LiveWatchlistPage extends StatefulWidget {
  const LiveWatchlistPage({super.key, required this.api});
  final ApiService api;

  @override
  State<LiveWatchlistPage> createState() => _LiveWatchlistPageState();
}

class _LiveWatchlistPageState extends State<LiveWatchlistPage> {
  Map<String, dynamic> ticks = {};
  String? err;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    _load();
    timer = Timer.periodic(const Duration(seconds: 3), (_) => _load());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await widget.api.getJson('/market/latest');
      if (mounted)
        setState(() {
          ticks = r;
          err = null;
        });
    } catch (e) {
      if (mounted) setState(() => err = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = ticks.entries.toList();
    return Column(
      children: [
        AppHeader(
          title: 'Watchlist',
          actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh))
          ],
        ),
        if (err != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(err!, style: const TextStyle(color: C.red)),
          ),
        Expanded(
          child: rows.isEmpty
              ? const Center(
                  child: Text('No subscribed live ticks yet.',
                      style: TextStyle(color: C.muted)))
              : ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, i) {
                    final e = rows[i];
                    final m = _m(e.value);
                    final p = _tickPrice(m);
                    final symbol = '${_pick(m, const [
                              'trading_symbol',
                              'symbol',
                              'name'
                            ]) ?? e.key}';
                    return ListTile(
                      title: Text(symbol,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(e.key,
                          style: const TextStyle(color: C.muted, fontSize: 11)),
                      trailing: Text(
                        p == 0 ? '--' : p.toStringAsFixed(2),
                        style: const TextStyle(
                            color: C.green, fontWeight: FontWeight.w900),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class LiveSignalsPage extends StatefulWidget {
  const LiveSignalsPage({super.key, required this.api});
  final ApiService api;

  @override
  State<LiveSignalsPage> createState() => _LiveSignalsPageState();
}

class _LiveSignalsPageState extends State<LiveSignalsPage> {
  List rows = [];
  String? err;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => busy = true);
    try {
      final v = await widget.api.getAny('/signals/lifecycle?limit=100');
      if (mounted)
        setState(() {
          rows = _l(v);
          err = null;
        });
    } catch (e) {
      if (mounted) setState(() => err = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: 'LION BRO Signals',
              back: true,
              actions: [
                IconButton(onPressed: _load, icon: const Icon(Icons.refresh))
              ],
            ),
            if (err != null)
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(err!, style: const TextStyle(color: C.red)),
              ),
            if (busy) const LinearProgressIndicator(color: C.red),
            Expanded(
              child: rows.isEmpty
                  ? const Center(
                      child: Text('No live signals.',
                          style: TextStyle(color: C.muted)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: rows.length,
                      itemBuilder: (context, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _LiveSignalCard(_m(rows[i])),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveSignalCard extends StatelessWidget {
  const _LiveSignalCard(this.m);
  final Map<String, dynamic> m;

  @override
  Widget build(BuildContext context) {
    final side = '${m['side'] ?? '--'}'.toUpperCase();
    final buy = side == 'BUY' || side == 'B';
    final tradeReady = m['trade_ready'] == true;
    final option = '${m['trading_symbol'] ?? m['symbol_key'] ?? '--'}';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: C.whiteCard, borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(option,
                    style: const TextStyle(
                        color: Colors.black, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text('Entry: ${m['entry'] ?? '--'}   SL: ${m['stop'] ?? '--'}',
                    style: const TextStyle(color: Colors.black54)),
                Text(
                    'Targets: ${m['target1'] ?? '--'} / ${m['target2'] ?? '--'}',
                    style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 5),
                Text(
                  tradeReady
                      ? 'TRADE READY'
                      : '${m['option_status'] ?? m['state'] ?? 'WAIT'}',
                  style: TextStyle(
                      color: tradeReady ? const Color(0xFF008E5C) : C.red,
                      fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          _Tag(buy ? 'BUY' : 'SELL', buy ? const Color(0xFF0AA865) : C.red),
        ],
      ),
    );
  }
}

class LiveScannerPage extends StatefulWidget {
  const LiveScannerPage({super.key, required this.api});
  final ApiService api;

  @override
  State<LiveScannerPage> createState() => _LiveScannerPageState();
}

class _LiveScannerPageState extends State<LiveScannerPage> {
  Map<String, dynamic> status = {};
  bool busy = false;
  String? msg;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await widget.api.getJson('/scanner/status');
      if (mounted)
        setState(() {
          status = r;
          msg = null;
        });
    } catch (e) {
      if (mounted) setState(() => msg = '$e');
    }
  }

  Future<void> _start(String group) async {
    setState(() => busy = true);
    try {
      await widget.api.postJson('/scanner/start', {'group': group});
      if (mounted) setState(() => msg = 'Scanner group $group started');
      await _load();
    } catch (e) {
      if (mounted) setState(() => msg = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _stop() async {
    setState(() => busy = true);
    try {
      await widget.api.postJson('/scanner/stop', {});
      if (mounted) setState(() => msg = 'Scanner stopped');
      await _load();
    } catch (e) {
      if (mounted) setState(() => msg = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _metric(String label, dynamic value, {Color? color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: C.panel,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: C.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: C.muted, fontSize: 11)),
          const SizedBox(height: 6),
          Text('$value',
              style: TextStyle(
                  color: color ?? C.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w900)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = status['active'] == true;
    final group = status['group'] ?? '--';
    final configured = status['configured_count'] ?? 0;
    final resolved = status['resolved_count'] ?? 0;
    final failed = status['failed_count'] ?? 0;
    final resolvedRows = _l(status['resolved']);
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          AppHeader(title: 'Market Scanner', back: true, actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh))
          ]),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              _StatusPill(
                  text: active ? 'RUNNING • $group' : 'STOPPED',
                  color: active ? C.green : C.muted),
              const Spacer(),
              Text('$resolved / $configured resolved',
                  style: const TextStyle(color: C.muted, fontSize: 12)),
            ]),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              _metric('Configured', configured),
              const SizedBox(width: 8),
              _metric('Resolved', resolved, color: C.green),
              const SizedBox(width: 8),
              _metric('Failed', failed, color: failed == 0 ? C.green : C.red),
            ]),
          ),
          if (msg != null)
            Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(msg!,
                    style: TextStyle(
                        color: msg!.contains('Exception') ? C.red : C.green))),
          const SizedBox(height: 10),
          Expanded(
            child: resolvedRows.isEmpty
                ? const Center(
                    child: Text('No scanner instruments resolved yet.',
                        style: TextStyle(color: C.muted)))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    itemCount: resolvedRows.length,
                    separatorBuilder: (_, __) =>
                        const Divider(color: C.border, height: 1),
                    itemBuilder: (_, i) {
                      final m = _m(resolvedRows[i]);
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('${m['symbol'] ?? '--'}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text(
                            '${m['exchange_segment'] ?? '--'} • token ${m['instrument_token'] ?? '--'}',
                            style:
                                const TextStyle(color: C.muted, fontSize: 11)),
                        trailing: const Icon(Icons.check_circle,
                            color: C.green, size: 18),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(
                  child: FilledButton(
                      onPressed: busy ? null : () => _start('A'),
                      child: const Text('Start A'))),
              const SizedBox(width: 8),
              Expanded(
                  child: FilledButton(
                      onPressed: busy ? null : () => _start('B'),
                      child: const Text('Start B'))),
              const SizedBox(width: 8),
              Expanded(
                  child: OutlinedButton(
                      onPressed: busy ? null : _stop,
                      child: const Text('Stop'))),
            ]),
          ),
        ]),
      ),
    );
  }
}

class LiveOrdersPage extends StatefulWidget {
  const LiveOrdersPage({super.key, required this.api});
  final ApiService api;

  @override
  State<LiveOrdersPage> createState() => _LiveOrdersPageState();
}

class _LiveOrdersPageState extends State<LiveOrdersPage> {
  List rows = [];
  String? err;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => busy = true);
    try {
      final v = await widget.api.getAny('/orders');
      final list = v is List ? v : _l(_m(v)['data'] ?? _m(v)['orders']);
      if (mounted)
        setState(() {
          rows = list;
          err = null;
        });
    } catch (e) {
      if (mounted) setState(() => err = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppHeader(title: 'Orders', actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh))
        ]),
        if (err != null)
          Padding(
              padding: const EdgeInsets.all(10),
              child: Text(err!, style: const TextStyle(color: C.red))),
        if (busy) const LinearProgressIndicator(color: C.red),
        Expanded(
          child: rows.isEmpty
              ? const Center(
                  child: Text('No broker orders.',
                      style: TextStyle(color: C.muted)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: rows.length,
                  itemBuilder: (context, i) {
                    final m = _m(rows[i]);
                    final side = '${m['transaction_type'] ?? m['side'] ?? '--'}'
                        .toUpperCase();
                    final buy = side == 'B' || side == 'BUY';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: C.whiteCard,
                          borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_sym(m),
                                    style: const TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w900)),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    _Tag(buy ? 'BUY' : 'SELL',
                                        buy ? const Color(0xFF0AA865) : C.red),
                                    const SizedBox(width: 8),
                                    Text(
                                        'Qty ${m['quantity'] ?? m['qty'] ?? '--'}',
                                        style: const TextStyle(
                                            color: Colors.black54)),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text(
                                    '${m['status'] ?? m['order_status'] ?? '--'}',
                                    style: const TextStyle(
                                        color: Color(0xFF008E5C),
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                          Text('${m['price'] ?? m['average_price'] ?? '--'}',
                              style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w900)),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class LivePortfolioPage extends StatefulWidget {
  const LivePortfolioPage({super.key, required this.api});
  final ApiService api;

  @override
  State<LivePortfolioPage> createState() => _LivePortfolioPageState();
}

class _LivePortfolioPageState extends State<LivePortfolioPage> {
  List positions = [];
  List holdings = [];
  Map<String, dynamic> limits = {};
  Map<String, dynamic> summary = {};
  String? err;
  bool busy = false;
  int section = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => busy = true);
    try {
      final v = await Future.wait([
        widget.api.getJson('/portfolio/positions/live'),
        widget.api.getAny('/portfolio/holdings'),
        widget.api.getAny('/portfolio/limits'),
      ]);
      final pm = _m(v[0]);
      if (!mounted) return;
      setState(() {
        positions = _l(pm['positions']);
        summary = _m(pm['summary']);
        holdings = _records(v[1], preferredKeys: const ['holdings']);
        limits = _m(v[2]);
        err = null;
      });
    } catch (e) {
      if (mounted) setState(() => err = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  List<Widget> _rows(List data, bool holding) {
    if (data.isEmpty)
      return const [
        Padding(
            padding: EdgeInsets.all(12),
            child: Text('No data', style: TextStyle(color: Colors.black54)))
      ];
    return data.take(20).map((x) {
      final m = _m(x);
      final pnl =
          _n(m['pnl'] ?? m['mtm'] ?? m['day_mtm'] ?? m['unrealized_pnl']);
      final ltp = _pick(m, const ['ltp', 'last_traded_price', 'last_price']);
      final quoteStatus = '${m['quote_status'] ?? ''}';
      final priceText = ltp == null
          ? '--'
          : '${_n(ltp).toStringAsFixed(2)}${quoteStatus == 'PREV_CLOSE' ? ' PREV CLOSE' : ''}';
      final sub = holding
          ? 'Qty ${m['quantity'] ?? m['qty'] ?? '--'} • LTP $priceText'
          : 'Qty ${m['net_quantity'] ?? m['quantity'] ?? '--'} • LTP $priceText';
      return _PnlRow(_sym(m), sub,
          pnl == 0 ? '--' : '${pnl >= 0 ? '+' : ''}${_money(pnl)}', pnl >= 0);
    }).toList();
  }

  Widget _fundRow(String label, dynamic value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(children: [
          Expanded(
              child:
                  Text(label, style: const TextStyle(color: Colors.black54))),
          Text(value == null ? '--' : _money(value),
              style: const TextStyle(
                  color: Colors.black, fontWeight: FontWeight.w900))
        ]),
      );

  Widget _funds() {
    final available = _deepPick(limits, const [
      'available_cash',
      'availablecash',
      'availableCash',
      'available_margin',
      'availableMargin',
      'net',
      'cash',
      'net_cash'
    ]);
    final used = _deepPick(limits, const [
      'used_margin',
      'utilized_margin',
      'utilised_margin',
      'margin_used',
      'usedMargin'
    ]);
    final collateral = _deepPick(
        limits, const ['collateral', 'collateral_value', 'collateralValue']);
    final exposure = _deepPick(
        limits, const ['exposure', 'exposure_margin', 'exposureMargin']);
    final total = _deepPick(limits, const [
      'total_limit',
      'totalLimit',
      'total_margin',
      'totalMargin',
      'net'
    ]);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: C.whiteCard, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Funds & Margin',
              style: TextStyle(
                  color: Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          _fundRow('Available Cash / Margin', available),
          const Divider(),
          _fundRow('Used Margin', used),
          const Divider(),
          _fundRow('Collateral', collateral),
          const Divider(),
          _fundRow('Exposure', exposure),
          const Divider(),
          _fundRow('Total Limit', total),
          const SizedBox(height: 8),
          const Text(
              'Values are shown only when supplied by the connected broker API.',
              style: TextStyle(color: Colors.black45, fontSize: 11)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['Positions', 'Holdings', 'Funds'];
    Widget content;
    if (section == 0) {
      content = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _WhiteInfoCard(children: _rows(positions, false)));
    } else if (section == 1) {
      content = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _WhiteInfoCard(children: _rows(holdings, true)));
    } else {
      content = _funds();
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: EdgeInsets.zero, children: [
        AppHeader(title: 'Portfolio', actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh))
        ]),
        if (err != null)
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(err!, style: const TextStyle(color: C.red))),
        if (busy) const LinearProgressIndicator(color: C.red),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
              children: List.generate(
                  3,
                  (i) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                            label: Text(titles[i]),
                            selected: section == i,
                            selectedColor: C.red,
                            onSelected: (_) => setState(() => section = i)),
                      ))),
        ),
        const SizedBox(height: 16),
        content,
        const SizedBox(height: 24),
      ]),
    );
  }
}

class _LivePortfolioPageState extends State<LivePortfolioPage> {
  List positions = [];
  List holdings = [];
  Map<String, dynamic> limits = {};
  Map<String, dynamic> summary = {};
  String? err;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => busy = true);
    try {
      final v = await Future.wait([
        widget.api.getJson('/portfolio/positions/live'),
        widget.api.getAny('/portfolio/holdings'),
        widget.api.getAny('/portfolio/limits'),
      ]);
      final pm = _m(v[0]);
      if (!mounted) return;
      setState(() {
        positions = _l(pm['positions']);
        summary = _m(pm['summary']);
        holdings = _records(v[1], preferredKeys: const ['holdings']);
        limits = _m(v[2]);
        err = null;
      });
    } catch (e) {
      if (mounted) setState(() => err = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  List<Widget> _rows(List data, bool holding) {
    if (data.isEmpty) {
      return const [
        Padding(
            padding: EdgeInsets.all(12),
            child: Text('No data', style: TextStyle(color: Colors.black54)))
      ];
    }
    return data.take(10).map((x) {
      final m = _m(x);
      final pnl =
          _n(m['pnl'] ?? m['mtm'] ?? m['day_mtm'] ?? m['unrealized_pnl']);
      final ltp = _pick(m, const ['ltp', 'last_traded_price', 'last_price']);
      final quoteStatus = '${m['quote_status'] ?? ''}';
      final priceText = ltp == null
          ? '--'
          : '${_n(ltp).toStringAsFixed(2)}${quoteStatus == 'PREV_CLOSE' ? ' PREV CLOSE' : ''}';
      final sub = holding
          ? 'Qty ${m['quantity'] ?? m['qty'] ?? '--'} • LTP $priceText'
          : 'Qty ${m['net_quantity'] ?? m['quantity'] ?? '--'} • LTP $priceText';
      return _PnlRow(_sym(m), sub,
          pnl == 0 ? '--' : '${pnl >= 0 ? '+' : ''}${_money(pnl)}', pnl >= 0);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cash = _deepPick(limits, const [
      'available_cash',
      'availablecash',
      'availableCash',
      'net',
      'cash',
      'net_cash'
    ]);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          AppHeader(title: 'Portfolio', actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh))
          ]),
          if (err != null)
            Padding(
                padding: const EdgeInsets.all(10),
                child: Text(err!, style: const TextStyle(color: C.red))),
          if (busy) const LinearProgressIndicator(color: C.red),
          const SizedBox(height: 12),
          const _SectionTitle('Open Positions'),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _WhiteInfoCard(children: _rows(positions, false))),
          const SizedBox(height: 16),
          const _SectionTitle('Holdings'),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _WhiteInfoCard(children: _rows(holdings, true))),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: C.panel, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Available Cash',
                      style: TextStyle(color: C.muted)),
                  const SizedBox(height: 5),
                  Text(cash == null ? '--' : '$cash',
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  Text(
                      'Open positions: ${summary['open_positions'] ?? positions.length}',
                      style: const TextStyle(color: C.muted)),
                  Text('Day MTM: ${_money(summary['day_mtm'])}',
                      style: const TextStyle(color: C.muted)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class LiveTradePage extends StatefulWidget {
  const LiveTradePage({
    super.key,
    required this.api,
    this.initialSymbol = '',
    this.initialPrice,
    this.initialSegment = 'NSEFO',
    this.initialBuy = true,
  });

  final ApiService api;
  final String initialSymbol;
  final double? initialPrice;
  final String initialSegment;
  final bool initialBuy;

  @override
  State<LiveTradePage> createState() => _LiveTradePageState();
}

class _LiveTradePageState extends State<LiveTradePage> {
  late final TextEditingController symbolController;
  late final TextEditingController priceController;
  final quantityController = TextEditingController(text: '1');
  late String segment;
  String product = 'MIS';
  String orderType = 'MKT';
  late bool buy;
  bool busy = false;
  String? msg;

  @override
  void initState() {
    super.initState();
    symbolController = TextEditingController(text: widget.initialSymbol);
    priceController = TextEditingController(
      text: widget.initialPrice != null && widget.initialPrice! > 0
          ? widget.initialPrice!.toStringAsFixed(2)
          : '',
    );
    segment = widget.initialSegment.isEmpty ? 'NSEFO' : widget.initialSegment;
    buy = widget.initialBuy;
  }

  @override
  void dispose() {
    symbolController.dispose();
    priceController.dispose();
    quantityController.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    final q = int.tryParse(quantityController.text.trim()) ?? 0;
    final p = _n(priceController.text);
    if (symbolController.text.trim().isEmpty || q <= 0 || p <= 0) {
      setState(() =>
          msg = 'Enter tradable symbol, quantity and live/reference price.');
      return;
    }
    setState(() => busy = true);
    try {
      final r = await widget.api.postJson('/execution/intent', {
        'exchange_segment': segment,
        'product': product,
        'price': orderType == 'MKT' ? '0' : priceController.text.trim(),
        'order_type': orderType,
        'quantity': q,
        'validity': 'DAY',
        'trading_symbol': symbolController.text.trim(),
        'transaction_type': buy ? 'B' : 'S',
        'trigger_price': '0',
        'amo': 'NO',
        'disclosed_quantity': '0',
        'reference_price': p,
        'live_price': p,
      });
      if (!mounted) return;
      if (r['ok'] != true) {
        setState(() => msg = 'Blocked: ${r['reasons']}');
        return;
      }

      final yes = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: C.panel,
          title: const Text('Confirm broker order'),
          content: Text(
            '${buy ? 'BUY' : 'SELL'} ${symbolController.text}\nQty $q • $product • $orderType\nReference ₹${p.toStringAsFixed(2)}\n\nThis is the final manual confirmation step.',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('CONFIRM')),
          ],
        ),
      );

      if (yes == true) {
        final x = await widget.api.postJson(
          '/execution/${r['intent_id']}/confirm',
          {'confirmation_token': r['confirmation_token'], 'live_price': p},
        );
        if (mounted) {
          setState(() => msg = x['ok'] == true
              ? 'Order submitted to broker'
              : 'Order failed: ${x['reasons'] ?? x}');
        }
      } else if (mounted) {
        setState(() => msg = 'Order cancelled before submission.');
      }
    } catch (e) {
      if (mounted) setState(() => msg = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const SizedBox(height: 6),
        const AppHeader(title: 'Manual Trade'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                  child: ChoiceChip(
                      label: const Text('BUY'),
                      selected: buy,
                      selectedColor: C.red,
                      onSelected: (_) => setState(() => buy = true))),
              const SizedBox(width: 8),
              Expanded(
                  child: ChoiceChip(
                      label: const Text('SELL'),
                      selected: !buy,
                      selectedColor: C.green,
                      onSelected: (_) => setState(() => buy = false))),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _TradeText(
            controller: symbolController,
            label: 'Trading Symbol',
            hint: 'Example: NIFTY26SEP24500CE'),
        _TradeText(
            controller: priceController,
            label: 'Live / Reference Price',
            hint: '126.40',
            number: true),
        _TradeText(
            controller: quantityController,
            label: 'Quantity',
            hint: '50',
            number: true),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['NSEFO', 'NSECM', 'BSEFO', 'MCX']
                .map((x) => ChoiceChip(
                    label: Text(x),
                    selected: segment == x,
                    onSelected: (_) => setState(() => segment = x)))
                .toList(),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            children: ['MIS', 'NRML', 'CNC']
                .map((x) => ChoiceChip(
                    label: Text(x),
                    selected: product == x,
                    onSelected: (_) => setState(() => product = x)))
                .toList(),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            children: ['MKT', 'L', 'SL', 'SL-M']
                .map((x) => ChoiceChip(
                    label: Text(x),
                    selected: orderType == x,
                    onSelected: (_) => setState(() => orderType = x)))
                .toList(),
          ),
        ),
        if (msg != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(msg!,
                style: TextStyle(
                    color:
                        msg!.startsWith('Order submitted') ? C.green : C.red)),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 56,
            child: FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: buy ? C.red : C.green),
              onPressed: busy ? null : _prepare,
              child: busy
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text('Prepare ${buy ? 'BUY' : 'SELL'} Order',
                      style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Safety: direct /orders/place is disabled by backend. This app uses execution intent → explicit confirmation only.',
            style: TextStyle(color: C.muted, fontSize: 11),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _TradeText extends StatelessWidget {
  const _TradeText(
      {required this.controller,
      required this.label,
      required this.hint,
      this.number = false});
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool number;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: TextField(
        controller: controller,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: C.panel2,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class LiveOptionPage extends StatefulWidget {
  const LiveOptionPage({super.key, required this.api});
  final ApiService api;

  @override
  State<LiveOptionPage> createState() => _LiveOptionPageState();
}

class _LiveOptionPageState extends State<LiveOptionPage> {
  List rows = [];
  String? err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final v = await widget.api.getAny('/signals/lifecycle?limit=100');
      final all = _l(v);
      if (!mounted) return;
      setState(() {
        rows = all.where((x) {
          final m = _m(x);
          final symbol = '${m['trading_symbol'] ?? ''}'.toUpperCase();
          return m['option_type'] != null ||
              symbol.contains('CE') ||
              symbol.contains('PE');
        }).toList();
        err = null;
      });
    } catch (e) {
      if (mounted) setState(() => err = '$e');
    }
  }

  String _segmentFor(Map m) {
    final direct = '${m['exchange_segment'] ?? m['segment'] ?? ''}'.trim();
    if (direct.isNotEmpty) return direct;
    final u =
        '${m['underlying_symbol'] ?? m['symbol'] ?? m['trading_symbol'] ?? ''}'
            .toUpperCase();
    return u.contains('SENSEX') ? 'BSEFO' : 'NSEFO';
  }

  double _priceFor(Map m) => _n(
        m['option_ltp'] ??
            m['ltp'] ??
            m['last_traded_price'] ??
            m['last_price'] ??
            m['price'],
      );

  void _openTrade(Map m, {required bool buy}) {
    final symbol = '${m['trading_symbol'] ?? m['tradingsymbol'] ?? ''}'.trim();
    final price = _priceFor(m);
    if (symbol.isEmpty || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Tradable symbol or genuine live premium is not available yet.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          body: SafeArea(
            child: LiveTradePage(
              api: widget.api,
              initialSymbol: symbol,
              initialPrice: price,
              initialSegment: _segmentFor(m),
              initialBuy: buy,
            ),
          ),
        ),
      ),
    );
  }

  void _openContract(Map m) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OptionContractPage(
          api: widget.api,
          contract: Map<String, dynamic>.from(m),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: 'Option Chain',
              back: true,
              actions: [
                IconButton(onPressed: _load, icon: const Icon(Icons.refresh))
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Icon(Icons.verified_outlined, color: C.green, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Resolved broker contracts — tap a contract or use BUY / SELL',
                    style: TextStyle(color: C.muted, fontSize: 12),
                  ),
                ),
              ]),
            ),
            if (err != null)
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(err!, style: const TextStyle(color: C.red)),
              ),
            Expanded(
              child: rows.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.table_chart_outlined,
                                color: C.muted, size: 42),
                            const SizedBox(height: 12),
                            const Text(
                              'No tradable option contract is resolved yet.',
                              style: TextStyle(
                                  color: C.text, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Only genuine broker-resolved CE/PE contracts with a live premium are shown here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: C.muted),
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: _load,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Refresh'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: rows.length,
                        itemBuilder: (c, i) {
                          final m = _m(rows[i]);
                          final symbol = '${m['trading_symbol'] ?? '--'}';
                          final ltp = _priceFor(m);
                          final optionType =
                              '${m['option_type'] ?? (symbol.toUpperCase().contains('PE') ? 'PE' : 'CE')}';
                          final tradeReady = m['trade_ready'] == true ||
                              (symbol != '--' && ltp > 0);
                          return InkWell(
                            onTap: () => _openContract(m),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: C.panel,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: tradeReady
                                        ? const Color(0x5536D399)
                                        : C.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          symbol,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 16),
                                        ),
                                      ),
                                      _StatusPill(
                                        text: optionType,
                                        color: optionType == 'PE'
                                            ? C.red
                                            : C.green,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 9),
                                  Wrap(
                                    spacing: 14,
                                    runSpacing: 8,
                                    children: [
                                      Text(
                                          'LTP ${ltp > 0 ? ltp.toStringAsFixed(2) : '--'}'),
                                      Text(
                                          'OI ${m['option_oi'] ?? m['oi'] ?? '--'}'),
                                      Text(
                                          'IV ${m['option_iv'] ?? m['iv'] ?? '--'}'),
                                      Text(
                                          'Δ ${m['option_delta'] ?? m['delta'] ?? '--'}'),
                                      Text('Expiry ${m['expiry'] ?? '--'}'),
                                      Text('Strike ${m['strike'] ?? '--'}'),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: FilledButton.icon(
                                          style: FilledButton.styleFrom(
                                              backgroundColor: C.green),
                                          onPressed: tradeReady
                                              ? () => _openTrade(m, buy: true)
                                              : null,
                                          icon: const Icon(Icons.arrow_upward,
                                              size: 17),
                                          label: const Text('BUY'),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: FilledButton.icon(
                                          style: FilledButton.styleFrom(
                                              backgroundColor: C.red),
                                          onPressed: tradeReady
                                              ? () => _openTrade(m, buy: false)
                                              : null,
                                          icon: const Icon(Icons.arrow_downward,
                                              size: 17),
                                          label: const Text('SELL'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class OptionContractPage extends StatelessWidget {
  const OptionContractPage(
      {super.key, required this.api, required this.contract});

  final ApiService api;
  final Map<String, dynamic> contract;

  double get _ltp => _n(
        contract['option_ltp'] ??
            contract['ltp'] ??
            contract['last_traded_price'] ??
            contract['last_price'] ??
            contract['price'],
      );

  String get _symbol =>
      '${contract['trading_symbol'] ?? contract['tradingsymbol'] ?? '--'}';

  String get _segment {
    final direct =
        '${contract['exchange_segment'] ?? contract['segment'] ?? ''}'.trim();
    if (direct.isNotEmpty) return direct;
    final u =
        '${contract['underlying_symbol'] ?? contract['symbol'] ?? _symbol}'
            .toUpperCase();
    return u.contains('SENSEX') ? 'BSEFO' : 'NSEFO';
  }

  void _trade(BuildContext context, bool buy) {
    if (_symbol == '--' || _ltp <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Genuine live premium is required before opening the trade ticket.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          body: SafeArea(
            child: LiveTradePage(
              api: api,
              initialSymbol: _symbol,
              initialPrice: _ltp,
              initialSegment: _segment,
              initialBuy: buy,
            ),
          ),
        ),
      ),
    );
  }

  Widget _metric(String label, Object? value) {
    final text = value == null || '$value'.trim().isEmpty ? '--' : '$value';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: C.panel2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: C.muted, fontSize: 11)),
          const SizedBox(height: 5),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final optionType =
        '${contract['option_type'] ?? (_symbol.toUpperCase().contains('PE') ? 'PE' : 'CE')}';
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(title: _symbol, back: true),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Text(
                        _ltp > 0 ? '₹${_ltp.toStringAsFixed(2)}' : '--',
                        style: const TextStyle(
                            fontSize: 30, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(width: 10),
                      _StatusPill(
                          text: optionType,
                          color: optionType == 'PE' ? C.red : C.green),
                    ],
                  ),
                  const SizedBox(height: 18),
                  GridView.count(
                    crossAxisCount: 2,
                    childAspectRatio: 2.2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    children: [
                      _metric('Strike', contract['strike']),
                      _metric('Expiry', contract['expiry']),
                      _metric('Open Interest',
                          contract['option_oi'] ?? contract['oi']),
                      _metric('IV', contract['option_iv'] ?? contract['iv']),
                      _metric('Delta',
                          contract['option_delta'] ?? contract['delta']),
                      _metric('Liquidity', contract['liquidity_score']),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: C.panel,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: C.border),
                    ),
                    child: const Text(
                      'Manual execution only. The trade ticket still passes through backend execution-intent checks and requires explicit final confirmation.',
                      style: TextStyle(color: C.muted, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: C.green,
                          minimumSize: const Size.fromHeight(54)),
                      onPressed: () => _trade(context, true),
                      child: const Text('BUY',
                          style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: C.red,
                          minimumSize: const Size.fromHeight(54)),
                      onPressed: () => _trade(context, false),
                      child: const Text('SELL',
                          style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Quick extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Quick({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
          width: 78,
          child: Column(children: [
            Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                    color: C.red, borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: Colors.white)),
            const SizedBox(height: 7),
            Text(label,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))
          ])));
}

class _SectionTitle extends StatelessWidget {
  final String t;
  const _SectionTitle(this.t);
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Text(t,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)));
}

class _Tag extends StatelessWidget {
  final String t;
  final Color c;
  const _Tag(this.t, this.c);
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration:
          BoxDecoration(color: c, borderRadius: BorderRadius.circular(7)),
      child: Text(t,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)));
}

class _TabChip extends StatelessWidget {
  final String t;
  final bool active;
  const _TabChip(this.t, this.active);
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
              color: active ? C.red.withOpacity(.14) : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: active ? C.red : C.border)),
          child: Text(t,
              style: TextStyle(
                  color: active ? C.red : C.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w800))));
}

class _MiniChip extends StatelessWidget {
  final String t;
  final bool active;
  const _MiniChip(this.t, {this.active = false});
  @override
  Widget build(BuildContext context) => Expanded(
      child: Container(
          margin: const EdgeInsets.only(right: 5),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
              color: active ? C.panel2 : C.panel,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: active ? C.muted : C.border)),
          child: Text(t,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: active ? C.text : C.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700))));
}

class _TradeButton extends StatelessWidget {
  final String t;
  final Color c;
  const _TradeButton(this.t, this.c);
  @override
  Widget build(BuildContext context) => SizedBox(
      height: 48,
      child: FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: c,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10))),
          onPressed: () {},
          child: Text(t, style: const TextStyle(fontWeight: FontWeight.w900))));
}

class _BottomAction extends StatelessWidget {
  final String t;
  final bool active;
  const _BottomAction(this.t, this.active);
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
          color: active ? C.red : C.panel2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? C.red : C.border)),
      child: Text(t,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)));
}

class _FieldLabel extends StatelessWidget {
  final String t;
  const _FieldLabel(this.t);
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 9),
      child: Text(t, style: const TextStyle(fontWeight: FontWeight.w800)));
}

class _SignalCard extends StatelessWidget {
  final String s, time, entry, sl, target, note;
  const _SignalCard(
      this.s, this.time, this.entry, this.sl, this.target, this.note);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: C.whiteCard, borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s,
                    style: const TextStyle(
                        color: Colors.black, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text('Entry: $entry   SL: $sl',
                    style: const TextStyle(color: Colors.black54)),
                Text('Targets: $target',
                    style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 5),
                Text(note,
                    style: const TextStyle(
                        color: Color(0xFF008E5C), fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Column(
            children: [
              const _Tag('BUY', Color(0xFF0AA865)),
              const SizedBox(height: 6),
              Text(time,
                  style: const TextStyle(color: Colors.black45, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScanRow extends StatelessWidget {
  final IconData i;
  final String t;
  const _ScanRow(this.i, this.t);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: C.border))),
      child: Row(
        children: [
          Icon(i, color: C.text, size: 20),
          const SizedBox(width: 12),
          Text(t, style: const TextStyle(fontWeight: FontWeight.w700)),
          const Spacer(),
          const Icon(Icons.chevron_right, color: C.muted),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final String s, side, q, p, status, time;
  const _OrderCard(this.s, this.side, this.q, this.p, this.status, this.time);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: C.whiteCard, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s,
                    style: const TextStyle(
                        color: Colors.black, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _Tag(side, side == 'BUY' ? const Color(0xFF0AA865) : C.red),
                    const SizedBox(width: 8),
                    Text(q, style: const TextStyle(color: Colors.black54)),
                  ],
                ),
                const SizedBox(height: 5),
                Text(status,
                    style: const TextStyle(
                        color: Color(0xFF008E5C), fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(p,
                  style: const TextStyle(
                      color: Colors.black, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(time,
                  style: const TextStyle(color: Colors.black45, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _WhiteInfoCard extends StatelessWidget {
  final List<Widget> children;
  const _WhiteInfoCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: C.whiteCard, borderRadius: BorderRadius.circular(16)),
      child: Column(children: children));
}

class _PnlRow extends StatelessWidget {
  final String a, b, c;
  final bool up;
  const _PnlRow(this.a, this.b, this.c, this.up);
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(a,
              style: const TextStyle(
                  color: Colors.black, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(b, style: const TextStyle(color: Colors.black54, fontSize: 12))
        ])),
        Text(c,
            style: TextStyle(
                color: up ? const Color(0xFF009E65) : C.red,
                fontWeight: FontWeight.w900))
      ]));
}

class LineChartPainter extends CustomPainter {
  const LineChartPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = C.green
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(0, size.height * 0.75);
    for (int i = 1; i < 9; i++) {
      final x = size.width * i / 8;
      final y = size.height * (0.75 - (i * 0.055) + (i % 2 == 0 ? 0.06 : 0.0));
      path.lineTo(x, y);
    }
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CandlePainter extends CustomPainter {
  const CandlePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = C.border
      ..strokeWidth = 0.6;
    for (int i = 1; i < 5; i++) {
      canvas.drawLine(Offset(0, size.height * i / 5),
          Offset(size.width, size.height * i / 5), grid);
    }

    final rnd = math.Random(4);
    double y = size.height * 0.62;
    for (int i = 0; i < 28; i++) {
      final x = 12 + i * (size.width - 24) / 28;
      final change = (rnd.nextDouble() - 0.43) * 34;
      final open = y;
      final close = (y - change).clamp(35.0, size.height - 35).toDouble();
      final high = math.min(open, close) - rnd.nextDouble() * 10;
      final low = math.max(open, close) + rnd.nextDouble() * 10;
      final up = close < open;
      final paint = Paint()
        ..color = up ? C.green : C.red
        ..strokeWidth = 1.6;
      canvas.drawLine(Offset(x, high), Offset(x, low), paint);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(x, (open + close) / 2),
          width: 7,
          height: math.max(4.0, (open - close).abs()),
        ),
        paint,
      );
      y = close;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
