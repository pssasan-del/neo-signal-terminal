import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/api_service.dart';

void main() => runApp(const NeoSignalApp());

class NeoSignalApp extends StatefulWidget {
  const NeoSignalApp({super.key});
  @override State<NeoSignalApp> createState() => _NeoSignalAppState();
}

class _NeoSignalAppState extends State<NeoSignalApp> {
  String baseUrl = 'http://129.154.35.105:8080';
  bool ready = false;
  @override void initState(){super.initState();_load();}
  Future<void> _load() async {final p=await SharedPreferences.getInstance();if(!mounted)return;setState((){baseUrl=p.getString('api')??baseUrl;ready=true;});}
  Future<void> _save(String v) async {final p=await SharedPreferences.getInstance();await p.setString('api',v);if(mounted)setState(()=>baseUrl=v);}
  @override Widget build(BuildContext context){
    final scheme=ColorScheme.fromSeed(seedColor:const Color(0xff00bfe8),brightness:Brightness.dark,surface:const Color(0xff07131f));
    return MaterialApp(
      debugShowCheckedModeBanner:false,
      title:'NEO Signal',
      theme:ThemeData(
        colorScheme:scheme,
        useMaterial3:true,
        scaffoldBackgroundColor:const Color(0xff04101a),
        fontFamily:'Roboto',
        cardTheme:const CardThemeData(elevation:0,margin:EdgeInsets.zero,color:Colors.transparent),
        navigationBarTheme:NavigationBarThemeData(
          height:70,
          elevation:0,
          backgroundColor:const Color(0xff071722),
          indicatorColor:const Color(0xff10394a),
          iconTheme:WidgetStateProperty.resolveWith((states)=>IconThemeData(color:states.contains(WidgetState.selected)?const Color(0xff35dcff):const Color(0xff7594a8))),
          labelTextStyle:WidgetStateProperty.resolveWith((states)=>TextStyle(fontWeight:states.contains(WidgetState.selected)?FontWeight.w900:FontWeight.w600,color:states.contains(WidgetState.selected)?const Color(0xff35dcff):const Color(0xff7895a8))),
        ),
        inputDecorationTheme:InputDecorationTheme(
          filled:true,
          fillColor:const Color(0xff0a1c29),
          border:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:const BorderSide(color:Color(0xffcbd9e8))),
          enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:const BorderSide(color:Color(0xffcbd9e8))),
          focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:const BorderSide(color:Color(0xff00a9d9),width:1.5)),
        ),
      ),
      home:ready?TerminalShell(baseUrl:baseUrl,onBaseUrl:_save):const Scaffold(body:Center(child:CircularProgressIndicator())),
    );
  }
}

class TerminalShell extends StatefulWidget {
  const TerminalShell({super.key,required this.baseUrl,required this.onBaseUrl});
  final String baseUrl; final ValueChanged<String> onBaseUrl;
  @override State<TerminalShell> createState()=>_TerminalShellState();
}
class _TerminalShellState extends State<TerminalShell>{
  int index=0; late ApiService api; StreamSubscription? tickSub; bool ws=false; Map<String,dynamic> lastTick={};
  @override void initState(){super.initState();api=ApiService(widget.baseUrl);_connect();}
  @override void didUpdateWidget(covariant TerminalShell old){super.didUpdateWidget(old);if(old.baseUrl!=widget.baseUrl){api=ApiService(widget.baseUrl);_connect();setState((){});}}
  void _connect(){tickSub?.cancel();tickSub=api.reconnectingTicks().listen((m){if(!mounted)return;if(m['_connection']=='connected'){setState(()=>ws=true);}else if(m['_connection']=='disconnected'){setState(()=>ws=false);}else{setState(()=>lastTick=m);}});}
  @override void dispose(){tickSub?.cancel();super.dispose();}
  @override Widget build(BuildContext context){final pages=[HomePage(api:api,ws:ws,lastTick:lastTick),SignalsPage(api:api),ScannerPage(api:api),TradePage(api:api),PortfolioPage(api:api),MorePage(api:api,initialUrl:widget.baseUrl,onUrl:widget.onBaseUrl,ws:ws)];return Scaffold(body:SafeArea(child:IndexedStack(index:index,children:pages)),bottomNavigationBar:NavigationBar(selectedIndex:index,onDestinationSelected:(v)=>setState(()=>index=v),destinations:const [NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home),label:'Home'),NavigationDestination(icon:Icon(Icons.bolt_outlined),selectedIcon:Icon(Icons.bolt),label:'Signals'),NavigationDestination(icon:Icon(Icons.radar),selectedIcon:Icon(Icons.radar),label:'Scanner'),NavigationDestination(icon:Icon(Icons.swap_horiz),label:'Trade'),NavigationDestination(icon:Icon(Icons.pie_chart_outline),selectedIcon:Icon(Icons.pie_chart),label:'Portfolio'),NavigationDestination(icon:Icon(Icons.grid_view_outlined),selectedIcon:Icon(Icons.grid_view),label:'More')]));}
}

class PageFrame extends StatelessWidget{
  const PageFrame({super.key,required this.title,required this.child,this.actions=const []});
  final String title; final Widget child; final List<Widget> actions;
  @override Widget build(BuildContext context)=>RefreshIndicator(
    onRefresh:()async{},
    child:DecoratedBox(
      decoration:const BoxDecoration(
        gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Color(0xff06131e),Color(0xff020b12)]),
      ),
      child:CustomScrollView(
        physics:const AlwaysScrollableScrollPhysics(),
        slivers:[
          SliverAppBar(
            backgroundColor:const Color(0xff06131e),
            surfaceTintColor:Colors.transparent,
            floating:true,
            title:Row(children:[
              Container(width:8,height:8,decoration:const BoxDecoration(shape:BoxShape.circle,color:Color(0xff00b8e6),boxShadow:[BoxShadow(color:Color(0x6600b8e6),blurRadius:10)])),
              const SizedBox(width:10),
              Text(title,style:const TextStyle(fontWeight:FontWeight.w900,letterSpacing:.2,color:Color(0xffdff9ff))),
            ]),
            actions:actions,
          ),
          SliverPadding(padding:const EdgeInsets.fromLTRB(16,4,16,28),sliver:SliverToBoxAdapter(child:child)),
        ],
      ),
    ),
  );
}

class HomePage extends StatefulWidget{const HomePage({super.key,required this.api,required this.ws,required this.lastTick});final ApiService api;final bool ws;final Map<String,dynamic> lastTick;@override State<HomePage>createState()=>_HomePageState();}
class _HomePageState extends State<HomePage>{Map<String,dynamic> boot={};String? error;Timer? timer;@override void initState(){super.initState();_load();timer=Timer.periodic(const Duration(seconds:5),(_)=>_load(silent:true));}@override void dispose(){timer?.cancel();super.dispose();}
 Future<void>_load({bool silent=false})async{try{final r=await widget.api.getJson('/app/bootstrap');if(mounted)setState((){boot=r;error=null;});}catch(e){if(mounted&&!silent)setState(()=>error='$e');}}
 @override Widget build(BuildContext context){final health=_map(boot['health']);final sum=_map(boot['position_summary']);final ex=_map(boot['execution']);final risk=_map(boot['risk']);final mtm=_num(sum['day_mtm']);final open=_int(sum['open_positions']);final indices=(boot['indices'] as List?)??[];return PageFrame(title:'NEO Signal',actions:[Padding(padding:const EdgeInsets.only(right:12),child:StatusPill(ok:widget.ws&&health['market_feed_stale']!=true,label:widget.ws?'LIVE':'RECONNECT'))],child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[if(error!=null)Notice(error!),BalanceCard(mtm:mtm,open:open,armed:ex['armed']==true,trading:risk['trading_enabled']==true),const SizedBox(height:14),if(indices.isNotEmpty)IndexStrip(items:indices)else const EmptyState(icon:Icons.sensors,text:'Connecting market indices'),const SizedBox(height:18),const SectionTitle('SYSTEM LINK'),const SizedBox(height:8),InfoTile(icon:Icons.cloud_done_outlined,title:'Kotak Neo session',value:health['authenticated']==true?'CONNECTED':'LOGIN REQUIRED',good:health['authenticated']==true),const SizedBox(height:8),InfoTile(icon:Icons.stream,title:'Market stream',value:health['market_stream_running']==true?'RUNNING':'OFFLINE',good:health['market_stream_running']==true),const SizedBox(height:8),InfoTile(icon:Icons.receipt_long_outlined,title:'Order stream',value:health['order_stream_running']==true?'RUNNING':'OFFLINE',good:health['order_stream_running']==true)]));}
}

class SignalsPage extends StatefulWidget{const SignalsPage({super.key,required this.api});final ApiService api;@override State<SignalsPage>createState()=>_SignalsPageState();}
class _SignalsPageState extends State<SignalsPage>{List<dynamic> items=[];String? error;bool busy=false;@override void initState(){super.initState();_load();}
 Future<void>_load()async{setState(()=>busy=true);try{final v=await widget.api.getAny('/signals/lifecycle');if(mounted)setState((){items=v is List?v:[];error=null;});}catch(e){if(mounted)setState(()=>error='$e');}finally{if(mounted)setState(()=>busy=false);}}
 void _open(Map<String,dynamic>x){showModalBottomSheet(context:context,isScrollControlled:true,showDragHandle:true,builder:(c)=>SignalSheet(signal:x));}
 @override Widget build(BuildContext context)=>PageFrame(title:'Signals',actions:[IconButton(onPressed:busy?null:_load,icon:const Icon(Icons.refresh))],child:Column(children:[if(error!=null)Notice(error!),if(items.isEmpty&&!busy)const EmptyState(icon:Icons.bolt_outlined,text:'Signal engine scanning • no qualified setup yet'),...items.map((v){final x=_map(v);return Padding(padding:const EdgeInsets.only(bottom:10),child:SignalCard(x,onTap:()=>_open(x)));})]));}


class ScannerPage extends StatefulWidget{
  const ScannerPage({super.key,required this.api});
  final ApiService api;
  @override State<ScannerPage> createState()=>_ScannerPageState();
}
class _ScannerPageState extends State<ScannerPage>{
  String mode='IDLE';
  String note='90-stock universe • run only the group you select';
  Future<void> _start(String group) async {
    setState((){mode='GROUP $group';note='45 stocks selected • scanner control ready';});
  }
  void _stop(){setState((){mode='IDLE';note='Scanner stopped';});}
  @override Widget build(BuildContext context)=>PageFrame(
    title:'AI Scanner',
    child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      RobotPanel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          Container(width:48,height:48,decoration:BoxDecoration(shape:BoxShape.circle,border:Border.all(color:const Color(0xff25d8ff)),boxShadow:const [BoxShadow(color:Color(0x5500d8ff),blurRadius:18)]),child:const Icon(Icons.radar,color:Color(0xff35dcff))),
          const SizedBox(width:12),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('KOTAK NEO SIGNAL RADAR',style:TextStyle(fontSize:11,letterSpacing:1.3,fontWeight:FontWeight.w900,color:Color(0xff35dcff))),
            const SizedBox(height:4),
            Text(mode,style:const TextStyle(fontSize:22,fontWeight:FontWeight.w900,color:Color(0xffe6fbff))),
          ])),
        ]),
        const SizedBox(height:14),
        Text(note,style:const TextStyle(color:Color(0xff91adbd),fontWeight:FontWeight.w700)),
        const SizedBox(height:14),
        const Wrap(spacing:7,runSpacing:7,children:[
          RobotChip(icon:Icons.timer_outlined,label:'5M STRICT',active:true),
          RobotChip(icon:Icons.show_chart,label:'EMA 9/21',active:true),
          RobotChip(icon:Icons.bolt,label:'BREAKOUT',active:true),
          RobotChip(icon:Icons.speed,label:'RSI',active:true),
          RobotChip(icon:Icons.insights,label:'WILLIAMS %R',active:true),
          RobotChip(icon:Icons.security,label:'R:R ≥ 1.85',active:true),
        ]),
      ])),
      const SizedBox(height:16),
      Row(children:[
        Expanded(child:FilledButton.icon(onPressed:()=>_start('A'),icon:const Icon(Icons.play_arrow),label:const Text('START A • 45'))),
        const SizedBox(width:10),
        Expanded(child:FilledButton.icon(onPressed:()=>_start('B'),icon:const Icon(Icons.play_arrow),label:const Text('START B • 45'))),
      ]),
      const SizedBox(height:10),
      OutlinedButton.icon(onPressed:_stop,icon:const Icon(Icons.stop_circle_outlined),label:const Text('STOP SCAN')),
      const SizedBox(height:18),
      const Notice('Scanner buttons are UI-safe in this build. Live 45/45 backend start/stop routes must be connected before they can control server scanning.'),
    ]),
  );
}

class SignalSheet extends StatelessWidget{const SignalSheet({super.key,required this.signal});final Map<String,dynamic>signal;@override Widget build(BuildContext context){final state='${signal['state']??'ACTIVE'}';return SafeArea(child:Padding(padding:const EdgeInsets.fromLTRB(20,4,20,24),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[Row(children:[Expanded(child:Text('${signal['symbol_key']??signal['symbol']??'Signal'}',style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w900))),Chip(label:Text(state))]),const SizedBox(height:14),MetricGrid(items:[('Entry',signal['entry']),('Stop',signal['stop']??signal['stop_loss']),('T1',signal['target1']),('T2',signal['target2']),('Side',signal['side']),('Last',signal['last_price'])]),const SizedBox(height:16),const Text('Execution remains protected by the risk gate, execution arm and one-time confirmation token.',style:TextStyle(color:Colors.black54))])));}}

class TradePage extends StatefulWidget{const TradePage({super.key,required this.api});final ApiService api;@override State<TradePage>createState()=>_TradePageState();}
class _TradePageState extends State<TradePage>{final underlying=TextEditingController(text:'NIFTY');final expiry=TextEditingController();final ltp=TextEditingController();final step=TextEditingController(text:'50');final qty=TextEditingController(text:'75');String type='CE';String product='MIS';Map<String,dynamic>? selected;List<dynamic> candidates=[];bool busy=false;String? message;
 @override void dispose(){for(final c in [underlying,expiry,ltp,step,qty]){c.dispose();}super.dispose();}
 Future<void>_scan()async{final u=_double(ltp.text),s=_double(step.text);if(u<=0||s<=0||expiry.text.trim().isEmpty){setState(()=>message='Enter expiry, underlying LTP and strike step.');return;}setState((){busy=true;message=null;});try{final r=await widget.api.postJson('/options/scan',{'underlying':underlying.text.trim().toUpperCase(),'expiry':expiry.text.trim(),'option_type':type,'underlying_ltp':u,'strike_step':s,'strikes_each_side':3,'exchange_segment':'NSEFO'});if(mounted)setState((){candidates=(r['candidates'] as List?)??[];selected=r['selected'] is Map?_map(r['selected']):null;message=selected==null?'No option passed quality filters.':'Best contract selected from live broker quotes.';});}catch(e){if(mounted)setState(()=>message='$e');}finally{if(mounted)setState(()=>busy=false);}}
 Future<void>_prepare()async{final x=selected;if(x==null)return;final q=int.tryParse(qty.text)??0;final price=_num(x['ltp']);if(q<=0||price<=0){setState(()=>message='Valid quantity and live premium required.');return;}setState(()=>busy=true);try{final r=await widget.api.postJson('/execution/intent',{'exchange_segment':'NSEFO','product':product,'price':'0','order_type':'MKT','quantity':q,'validity':'DAY','trading_symbol':'${x['trading_symbol']??''}','transaction_type':'B','trigger_price':'0','amo':'NO','disclosed_quantity':'0','reference_price':price,'live_price':price,'open_positions':0,'day_pnl':0.0});if(r['ok']!=true){throw Exception('Blocked: ${r['reasons']}');}if(!mounted)return;await showDialog(context:context,barrierDismissible:false,builder:(c)=>ConfirmTradeDialog(api:widget.api,intent:r,livePrice:price));}catch(e){if(mounted)setState(()=>message='$e');}finally{if(mounted)setState(()=>busy=false);}}
 @override Widget build(BuildContext context)=>PageFrame(title:'Option Trade',child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[TextField(controller:underlying,decoration:const InputDecoration(labelText:'Underlying')),const SizedBox(height:10),TextField(controller:expiry,decoration:const InputDecoration(labelText:'Expiry',hintText:'Broker expiry format')),const SizedBox(height:10),Row(children:[Expanded(child:TextField(controller:ltp,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Underlying LTP'))),const SizedBox(width:10),Expanded(child:TextField(controller:step,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Strike step')))]),const SizedBox(height:10),Row(children:[Expanded(child:SegmentedButton<String>(segments:const [ButtonSegment(value:'CE',label:Text('CE')),ButtonSegment(value:'PE',label:Text('PE'))],selected:{type},onSelectionChanged:(v)=>setState(()=>type=v.first))),const SizedBox(width:10),Expanded(child:DropdownButtonFormField<String>(value:product,items:const [DropdownMenuItem(value:'MIS',child:Text('MIS')),DropdownMenuItem(value:'NRML',child:Text('NRML'))],onChanged:(v)=>setState(()=>product=v??product),decoration:const InputDecoration(labelText:'Product')))]),const SizedBox(height:12),FilledButton.icon(onPressed:busy?null:_scan,icon:const Icon(Icons.manage_search),label:Text(busy?'Checking live quotes…':'Find best option')),if(message!=null)Padding(padding:const EdgeInsets.only(top:10),child:Notice(message!)),if(selected!=null)...[const SizedBox(height:8),SelectedOptionCard(x:selected!),const SizedBox(height:10),TextField(controller:qty,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Quantity')),const SizedBox(height:14),SwipeGuard(label:'SWIPE TO PREPARE BUY',onTriggered:_prepare)],if(candidates.isNotEmpty)...[const SizedBox(height:20),const SectionTitle('Candidate quality'),const SizedBox(height:8),OptionChainTable(rows:candidates.take(10).map(_map).toList(),selected:selected,onSelect:(x)=>setState(()=>selected=x))]]));}

class ConfirmTradeDialog extends StatefulWidget{const ConfirmTradeDialog({super.key,required this.api,required this.intent,required this.livePrice});final ApiService api;final Map<String,dynamic>intent;final double livePrice;@override State<ConfirmTradeDialog>createState()=>_ConfirmTradeDialogState();}
class _ConfirmTradeDialogState extends State<ConfirmTradeDialog>{bool busy=false;String? error;@override Widget build(BuildContext context){final s=_map(widget.intent['summary']);return AlertDialog(title:const Text('Confirm live order'),content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${s['side']}  ${s['quantity']} × ${s['symbol']}',style:const TextStyle(fontWeight:FontWeight.w900,fontSize:17)),const SizedBox(height:8),Text('Live premium: \u20B9${widget.livePrice.toStringAsFixed(2)}'),Text('${s['order_type']??'MKT'} • ${s['product']??''}'),const SizedBox(height:12),const Text('This confirmation token is one-time and short-lived.',style:TextStyle(color:Colors.black54)),if(error!=null)Padding(padding:const EdgeInsets.only(top:10),child:Text(error!,style:const TextStyle(color:Colors.red))) ]),actions:[TextButton(onPressed:busy?null:()=>Navigator.pop(context),child:const Text('Cancel')),FilledButton(onPressed:busy?null:()async{setState(()=>busy=true);try{final r=await widget.api.postJson('/execution/${widget.intent['intent_id']}/confirm',{'confirmation_token':widget.intent['confirmation_token'],'live_price':widget.livePrice,'open_positions':0,'day_pnl':0.0});if(!mounted)return;Navigator.pop(context);ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(r['ok']==true?'Order submitted to Kotak':'Order blocked: ${r['reasons']}')));}catch(e){if(mounted)setState((){error='$e';busy=false;});}},child:Text(busy?'Submitting…':'CONFIRM BUY'))]);}}

class PortfolioPage extends StatefulWidget{const PortfolioPage({super.key,required this.api});final ApiService api;@override State<PortfolioPage>createState()=>_PortfolioPageState();}
class _PortfolioPageState extends State<PortfolioPage>{List<dynamic> p=[];Map<String,dynamic> sum={};String? error;bool busy=false;@override void initState(){super.initState();_load();}
 Future<void>_load()async{setState(()=>busy=true);try{final r=await widget.api.getJson('/portfolio/positions/live');if(mounted)setState((){p=(r['positions'] as List?)??[];sum=_map(r['summary']);error=null;});}catch(e){if(mounted)setState(()=>error='$e');}finally{if(mounted)setState(()=>busy=false);}}
 Future<void>_refreshBroker()async{try{await widget.api.postJson('/portfolio/positions/refresh',{});await _load();}catch(e){if(mounted)setState(()=>error='$e');}}
 @override Widget build(BuildContext context)=>PageFrame(title:'Portfolio',actions:[IconButton(onPressed:busy?null:_refreshBroker,icon:const Icon(Icons.sync))],child:Column(children:[PnlHeader(value:_num(sum['day_mtm'])),const SizedBox(height:14),if(error!=null)Notice(error!),if(p.isEmpty&&!busy)const EmptyState(icon:Icons.inbox_outlined,text:'No open positions'),...p.map((v)=>Padding(padding:const EdgeInsets.only(bottom:10),child:PositionTile(api:widget.api,x:_map(v),onDone:_load)))]));}

class PositionTile extends StatelessWidget {
  const PositionTile({super.key, required this.api, required this.x, required this.onDone});
  final ApiService api;
  final Map<String, dynamic> x;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final q = _int(x['net_quantity'] ?? x['quantity']);
    final pnl = _num(x['mtm'] ?? x['pnl']);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${x['trading_symbol'] ?? x['symbol'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 3),
                      Text('Qty $q  •  Avg ${x['average_price'] ?? '-'}  •  LTP ${x['ltp'] ?? '-'}', style: const TextStyle(color: Colors.black54)),
                    ],
                  ),
                ),
                Text(
                  _money(pnl),
                  style: TextStyle(fontWeight: FontWeight.w900, color: pnl >= 0 ? Colors.green.shade700 : Colors.red.shade700),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: q == 0 ? null : () => showDialog(context: context, builder: (c) => ExitPlanDialog(api: api, position: x)),
                  child: const Text('SL / Targets'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: q == 0 ? null : () async {
                    try {
                      final r = await api.postJson('/portfolio/exit-intent', {'position_key': '${x['key']}'});
                      if (!context.mounted) return;
                      if (r['ok'] != true) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exit blocked: ${r['reasons']}')));
                        return;
                      }
                      await showDialog(
                        context: context,
                        builder: (c) => ConfirmTradeDialog(api: api, intent: r, livePrice: _num(x['ltp'] ?? x['average_price'])),
                      );
                      onDone();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                      }
                    }
                  },
                  child: const Text('Prepare Exit'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class MorePage extends StatefulWidget{const MorePage({super.key,required this.api,required this.initialUrl,required this.onUrl,required this.ws});final ApiService api;final String initialUrl;final ValueChanged<String> onUrl;final bool ws;@override State<MorePage>createState()=>_MorePageState();}
class _MorePageState extends State<MorePage>{late final TextEditingController c=TextEditingController(text:widget.initialUrl);Map<String,dynamic> risk={};Map<String,dynamic> execution={};dynamic orders,holdings,limits,journal;String? msg;bool busy=false;@override void initState(){super.initState();_load();}@override void dispose(){c.dispose();super.dispose();}
 Future<void>_load()async{try{final b=await widget.api.getJson('/app/bootstrap');if(mounted)setState((){risk=_map(b['risk']);execution=_map(b['execution']);});}catch(e){if(mounted)setState(()=>msg='$e');}}
 Future<void>_toggleRisk(bool on)async{try{final r=await widget.api.postJson('/risk/trading',{'enabled':on});setState(()=>risk=r);}catch(e){setState(()=>msg='$e');}}
 Future<void>_toggleArm(bool on)async{try{final r=await widget.api.postJson('/execution/arm',{'enabled':on});setState(()=>execution=r);}catch(e){setState(()=>msg='$e');}}
 Future<void>_login()async{await showDialog(context:context,builder:(c)=>LoginDialog(api:widget.api));await _load();}
 Future<void>_logout()async{try{await widget.api.postJson('/auth/logout',{});await _load();}catch(e){setState(()=>msg='$e');}}
 Future<void>_syncCore()async{try{final r=await widget.api.postJson('/instruments/sync-core',{});setState(()=>msg='Core indices synced: ${r['indices']}');}catch(e){setState(()=>msg='$e');}}
 Future<void>_recover()async{try{final r=await widget.api.postJson('/system/recover',{});setState(()=>msg='Recovery complete: ${r['subscriptions']}');await _load();}catch(e){setState(()=>msg='$e');}}
 Future<void>_account()async{setState(()=>busy=true);try{final values=await Future.wait([widget.api.getAny('/orders'),widget.api.getAny('/portfolio/holdings'),widget.api.getAny('/portfolio/limits'),widget.api.getAny('/journal?limit=30')]);if(mounted)setState((){orders=values[0];holdings=values[1];limits=values[2];journal=values[3];msg=null;});}catch(e){if(mounted)setState(()=>msg='$e');}finally{if(mounted)setState(()=>busy=false);}}
 @override Widget build(BuildContext context)=>PageFrame(title:'More',child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[const SectionTitle('Kotak session'),const SizedBox(height:8),Row(children:[Expanded(child:FilledButton.icon(onPressed:_login,icon:const Icon(Icons.login),label:const Text('Login TOTP'))),const SizedBox(width:8),Expanded(child:OutlinedButton.icon(onPressed:_logout,icon:const Icon(Icons.logout),label:const Text('Logout')))]),const SizedBox(height:8),OutlinedButton.icon(onPressed:_syncCore,icon:const Icon(Icons.sync_alt),label:const Text('Sync NIFTY • BANKNIFTY • SENSEX')),const SizedBox(height:8),OutlinedButton.icon(onPressed:_recover,icon:const Icon(Icons.restore),label:const Text('Recover subscriptions & positions')),const SizedBox(height:20),const SectionTitle('Safety controls'),const SizedBox(height:8),SwitchListTile(tileColor:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14)),title:const Text('Risk trading gate'),subtitle:const Text('Must be ON before execution can arm'),value:risk['trading_enabled']==true,onChanged:_toggleRisk),const SizedBox(height:8),SwitchListTile(tileColor:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14)),title:const Text('Execution arm'),subtitle:const Text('Second gate for live order submission'),value:execution['armed']==true,onChanged:_toggleArm),const SizedBox(height:8),FilledButton.tonalIcon(onPressed:()async{try{await widget.api.postJson('/execution/kill-switch',{});await _load();if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Kill switch activated')));}catch(e){setState(()=>msg='$e');}},icon:const Icon(Icons.emergency),label:const Text('KILL SWITCH')),const SizedBox(height:20),const SectionTitle('Account'),const SizedBox(height:8),OutlinedButton.icon(onPressed:busy?null:_account,icon:const Icon(Icons.sync),label:Text(busy?'Loading…':'Load Orders • Holdings • Funds')),if(orders!=null)JsonPanel(title:'Orders',data:orders),if(holdings!=null)JsonPanel(title:'Holdings',data:holdings),if(limits!=null)JsonPanel(title:'Funds / Limits',data:limits),if(journal!=null)JsonPanel(title:'Trade Journal',data:journal),const SizedBox(height:20),const SectionTitle('Connection'),const SizedBox(height:8),TextField(controller:c,decoration:InputDecoration(labelText:'Backend URL',suffixIcon:Icon(widget.ws?Icons.cloud_done:Icons.cloud_off))),const SizedBox(height:10),FilledButton(onPressed:()async{final v=c.text.trim().replaceAll(RegExp(r'/$'),'');widget.onUrl(v);setState(()=>msg='Connection saved');},child:const Text('Save connection')),if(msg!=null)Padding(padding:const EdgeInsets.only(top:10),child:Notice(msg!))]));}

class RobotPanel extends StatelessWidget{
  const RobotPanel({super.key,required this.child,this.padding=const EdgeInsets.all(16),this.glow=true});
  final Widget child; final EdgeInsets padding; final bool glow;
  @override Widget build(BuildContext context)=>Container(
    decoration:BoxDecoration(
      gradient:const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Color(0xff0c2230),Color(0xff071620)]),
      borderRadius:BorderRadius.circular(18),
      border:Border.all(color:const Color(0xff1d8eaa),width:1),
      boxShadow:glow?const [BoxShadow(color:Color(0x4400cfff),blurRadius:16,spreadRadius:1),BoxShadow(color:Color(0x220078e6),blurRadius:30,offset:Offset(0,8))]:const [],
    ),
    child:ClipRRect(
      borderRadius:BorderRadius.circular(18),
      child:Stack(children:[
        Positioned(right:-36,top:-48,child:Container(width:120,height:120,decoration:const BoxDecoration(shape:BoxShape.circle,gradient:RadialGradient(colors:[Color(0x4400e5ff),Color(0x0000d8ff)])))),
        Padding(padding:padding,child:child),
      ]),
    ),
  );
}

class RobotScanLine extends StatefulWidget{const RobotScanLine({super.key});@override State<RobotScanLine>createState()=>_RobotScanLineState();}
class _RobotScanLineState extends State<RobotScanLine>with SingleTickerProviderStateMixin{
  late final AnimationController c=AnimationController(vsync:this,duration:const Duration(milliseconds:2600))..repeat();
  @override void dispose(){c.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>IgnorePointer(child:LayoutBuilder(builder:(context,b)=>AnimatedBuilder(animation:c,builder:(context,_){return Positioned(top:(b.maxHeight-2)*c.value,left:0,right:0,child:Container(height:2,decoration:const BoxDecoration(gradient:LinearGradient(colors:[Color(0x0000bfe8),Color(0x7700bfe8),Color(0x0000bfe8)]))));})));
}

class BalanceCard extends StatelessWidget{
  const BalanceCard({super.key,required this.mtm,required this.open,required this.armed,required this.trading});
  final double mtm; final int open; final bool armed,trading;
  @override Widget build(BuildContext context)=>RobotPanel(
    padding:EdgeInsets.zero,
    child:Stack(children:[
      const RobotScanLine(),
      Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('ACCOUNT CORE',style:TextStyle(fontSize:10,fontWeight:FontWeight.w900,letterSpacing:1.5,color:Color(0xff4b7596))),SizedBox(height:2),Text('TODAY MTM',style:TextStyle(fontSize:13,fontWeight:FontWeight.w800,color:Color(0xff163651)))])),
          Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),decoration:BoxDecoration(color:const Color(0xffe7fbff),borderRadius:BorderRadius.circular(20),border:Border.all(color:const Color(0xff9cdeed))),child:const Row(children:[Icon(Icons.memory,size:14,color:Color(0xff008db5)),SizedBox(width:5),Text('NEO CORE',style:TextStyle(fontSize:10,fontWeight:FontWeight.w900,color:Color(0xff007eaa)))])),
        ]),
        const SizedBox(height:7),
        Text(_money(mtm,sign:true),style:Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.w900,letterSpacing:.3,color:mtm>=0?const Color(0xff159447):const Color(0xffd43b45))),
        const SizedBox(height:15),
        Wrap(spacing:8,runSpacing:8,children:[RobotChip(icon:Icons.work_outline,label:'$open OPEN',active:open>0),RobotChip(icon:Icons.shield_outlined,label:trading?'RISK ON':'RISK OFF',active:trading),RobotChip(icon:armed?Icons.lock_open:Icons.lock_outline,label:armed?'ARMED':'DISARMED',active:armed)]),
      ])),
    ]),
  );
}

class RobotChip extends StatelessWidget{const RobotChip({super.key,required this.icon,required this.label,required this.active});final IconData icon;final String label;final bool active;@override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.symmetric(horizontal:11,vertical:8),decoration:BoxDecoration(gradient:LinearGradient(colors:active?const [Color(0xffe9fff3),Color(0xfff8fffb)]:const [Color(0xfff4f8fb),Color(0xfffbfdff)]),borderRadius:BorderRadius.circular(12),border:Border.all(color:active?const Color(0xff9bddb9):const Color(0xffcbd9e5))),child:Row(mainAxisSize:MainAxisSize.min,children:[Icon(icon,size:16,color:active?const Color(0xff159447):const Color(0xff687b8d)),const SizedBox(width:6),Text(label,style:TextStyle(fontSize:12,fontWeight:FontWeight.w900,color:active?const Color(0xff126d38):const Color(0xff41576c)))]));}

class PnlHeader extends StatelessWidget{const PnlHeader({super.key,required this.value});final double value;@override Widget build(BuildContext context)=>RobotPanel(child:Row(children:[Container(width:44,height:44,decoration:BoxDecoration(shape:BoxShape.circle,color:const Color(0xffe4f9ff),border:Border.all(color:const Color(0xff9fddec))),child:const Icon(Icons.insights,color:Color(0xff008db5))),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('LIVE MTM',style:TextStyle(fontSize:11,fontWeight:FontWeight.w900,letterSpacing:1.2,color:Color(0xff54738c))),Text(_money(value),style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w900,color:const Color(0xff153650)))]))]));}

class StatusPill extends StatelessWidget{const StatusPill({super.key,required this.ok,required this.label});final bool ok;final String label;@override Widget build(BuildContext context)=>Container(margin:const EdgeInsets.symmetric(vertical:8),padding:const EdgeInsets.symmetric(horizontal:11,vertical:7),decoration:BoxDecoration(color:ok?const Color(0xffeafff1):const Color(0xfffff7e8),borderRadius:BorderRadius.circular(20),border:Border.all(color:ok?const Color(0xff83d8a9):const Color(0xffffca77)),boxShadow:[BoxShadow(color:ok?const Color(0x2200aa66):const Color(0x22ff9900),blurRadius:10)]),child:Row(mainAxisSize:MainAxisSize.min,children:[Icon(Icons.circle,size:9,color:ok?const Color(0xff19a85a):const Color(0xffed9a13)),const SizedBox(width:6),Text(label,style:TextStyle(fontSize:11,fontWeight:FontWeight.w900,letterSpacing:.6,color:ok?const Color(0xff11723e):const Color(0xff9a6200)))]));}

class SectionTitle extends StatelessWidget{const SectionTitle(this.t,{super.key});final String t;@override Widget build(BuildContext context)=>Row(children:[Container(width:3,height:18,decoration:BoxDecoration(color:const Color(0xff00a9d9),borderRadius:BorderRadius.circular(3),boxShadow:const [BoxShadow(color:Color(0x5500a9d9),blurRadius:8)])),const SizedBox(width:8),Text(t,style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.w900,letterSpacing:.7,color:const Color(0xff17364f)))]);}

class InfoTile extends StatelessWidget{const InfoTile({super.key,required this.icon,required this.title,required this.value,required this.good});final IconData icon;final String title,value;final bool good;@override Widget build(BuildContext context)=>RobotPanel(glow:false,padding:const EdgeInsets.symmetric(horizontal:14,vertical:8),child:ListTile(contentPadding:EdgeInsets.zero,leading:Container(width:42,height:42,decoration:BoxDecoration(shape:BoxShape.circle,color:const Color(0xffedf9ff),border:Border.all(color:const Color(0xffbee2f0))),child:Icon(icon,color:const Color(0xff087ca7))),title:Text(title,style:const TextStyle(fontWeight:FontWeight.w800,color:Color(0xff1b3850))),trailing:Row(mainAxisSize:MainAxisSize.min,children:[Icon(Icons.circle,size:8,color:good?const Color(0xff19a85a):const Color(0xffe39a22)),const SizedBox(width:6),Text(value,style:TextStyle(fontSize:12,fontWeight:FontWeight.w900,color:good?const Color(0xff138044):const Color(0xffa76b09))) ])));}

class Notice extends StatelessWidget{const Notice(this.t,{super.key});final String t;@override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.symmetric(vertical:8),child:Container(decoration:BoxDecoration(color:const Color(0xfffff9ea),borderRadius:BorderRadius.circular(14),border:Border.all(color:const Color(0xffffd98c))),padding:const EdgeInsets.all(12),child:Text(t,style:const TextStyle(color:Color(0xff745000)))));}

class EmptyState extends StatelessWidget{const EmptyState({super.key,required this.icon,required this.text});final IconData icon;final String text;@override Widget build(BuildContext context)=>RobotPanel(glow:false,child:Padding(padding:const EdgeInsets.symmetric(vertical:24),child:Column(children:[Container(width:58,height:58,decoration:BoxDecoration(shape:BoxShape.circle,gradient:const LinearGradient(colors:[Color(0xffe9f9ff),Color(0xfff8fdff)]),border:Border.all(color:const Color(0xffa9ddeb)),boxShadow:const [BoxShadow(color:Color(0x4400cfff),blurRadius:18)]),child:Icon(icon,size:28,color:const Color(0xff008eb8))),const SizedBox(height:12),Text(text,textAlign:TextAlign.center,style:const TextStyle(color:Color(0xff5c7183),fontWeight:FontWeight.w700))])));}

class SignalCard extends StatelessWidget{const SignalCard(this.x,{super.key,required this.onTap});final Map<String,dynamic>x;final VoidCallback onTap;@override Widget build(BuildContext context){final side='${x['side']??''}'.toUpperCase();final buy=side=='BUY';return GestureDetector(onTap:onTap,child:RobotPanel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Container(width:38,height:38,decoration:BoxDecoration(shape:BoxShape.circle,color:buy?const Color(0xffe9fff2):const Color(0xffffeef0),border:Border.all(color:buy?const Color(0xff9bdfba):const Color(0xffffb5bd))),child:Icon(buy?Icons.trending_up:Icons.trending_down,color:buy?const Color(0xff159447):const Color(0xffcf3744))),const SizedBox(width:10),Expanded(child:Text('${x['symbol_key']??x['symbol']??'Signal'}',style:const TextStyle(fontWeight:FontWeight.w900,fontSize:16,color:Color(0xff17364f)))),Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:5),decoration:BoxDecoration(color:buy?const Color(0xffeafff1):const Color(0xffffeef0),borderRadius:BorderRadius.circular(12)),child:Text(side,style:TextStyle(fontWeight:FontWeight.w900,color:buy?const Color(0xff117b40):const Color(0xffb42e38))))]),const SizedBox(height:12),Text('ENTRY  ${x['entry']??'-'}    SL  ${x['stop']??x['stop_loss']??'-'}    T1  ${x['target1']??'-'}',style:const TextStyle(fontSize:12,fontWeight:FontWeight.w800,color:Color(0xff536d81))),const SizedBox(height:8),Row(children:[const Icon(Icons.bolt,size:15,color:Color(0xff00a9d9)),const SizedBox(width:4),Text('${x['state']??'ACTIVE'}',style:const TextStyle(fontSize:11,fontWeight:FontWeight.w900,color:Color(0xff087ca7))),const Spacer(),const Icon(Icons.chevron_right,color:Color(0xff7992a7))])])));}}

class MetricGrid extends StatelessWidget{const MetricGrid({super.key,required this.items});final List<(String,dynamic)>items;@override Widget build(BuildContext context)=>Wrap(spacing:8,runSpacing:8,children:items.map((e)=>Container(width:(MediaQuery.sizeOf(context).width-56)/2,padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:const Color(0xfff5f6f9),borderRadius:BorderRadius.circular(12)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(e.$1,style:const TextStyle(color:Colors.black45,fontSize:12)),const SizedBox(height:3),Text('${e.$2??'-'}',style:const TextStyle(fontWeight:FontWeight.w900))]))).toList());}
class SelectedOptionCard extends StatelessWidget{const SelectedOptionCard({super.key,required this.x});final Map<String,dynamic>x;@override Widget build(BuildContext context)=>Card(color:Colors.white,child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Text('${x['trading_symbol']??'-'}',style:const TextStyle(fontWeight:FontWeight.w900,fontSize:17))),Chip(label:Text('SCORE ${x['score']??'-'}'))]),const SizedBox(height:4),Text('\u20B9${_num(x['ltp']).toStringAsFixed(2)}  •  Strike ${x['strike']??'-'}  •  Spread ${x['spread_pct']??'n/a'}%',style:const TextStyle(color:Colors.black54)),if((x['reasons'] as List?)?.isNotEmpty==true)Padding(padding:const EdgeInsets.only(top:6),child:Text('${x['reasons']}',style:const TextStyle(fontSize:12,color:Colors.black45))) ])));}
class CandidateTile extends StatelessWidget{const CandidateTile({super.key,required this.x,required this.selected,required this.onTap});final Map<String,dynamic>x;final bool selected;final VoidCallback onTap;@override Widget build(BuildContext context)=>Card(color:selected?Theme.of(context).colorScheme.primaryContainer:Colors.white,child:ListTile(onTap:onTap,title:Text('${x['trading_symbol']??'-'}',style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('LTP ${x['ltp']??'-'}  •  Spread ${x['spread_pct']??'n/a'}%'),trailing:Text('${x['score']??'-'}')));}
class OptionChainTable extends StatelessWidget{const OptionChainTable({super.key,required this.rows,required this.selected,required this.onSelect});final List<Map<String,dynamic>>rows;final Map<String,dynamic>?selected;final ValueChanged<Map<String,dynamic>>onSelect;@override Widget build(BuildContext context)=>Card(color:Colors.white,child:Padding(padding:const EdgeInsets.all(8),child:Column(children:[const Row(children:[Expanded(flex:3,child:Text('Contract',style:TextStyle(fontWeight:FontWeight.w800))),Expanded(child:Text('LTP',textAlign:TextAlign.right,style:TextStyle(fontWeight:FontWeight.w800))),Expanded(child:Text('Spread',textAlign:TextAlign.right,style:TextStyle(fontWeight:FontWeight.w800))),Expanded(child:Text('Score',textAlign:TextAlign.right,style:TextStyle(fontWeight:FontWeight.w800)))]),const Divider(),...rows.map((x){final isSel=selected!=null&&('${x['instrument_token']??x['token']}'=='${selected!['instrument_token']??selected!['token']}');return InkWell(onTap:()=>onSelect(x),borderRadius:BorderRadius.circular(10),child:Container(padding:const EdgeInsets.symmetric(vertical:10,horizontal:4),decoration:BoxDecoration(color:isSel?Theme.of(context).colorScheme.primaryContainer:null,borderRadius:BorderRadius.circular(10)),child:Row(children:[Expanded(flex:3,child:Text('${x['trading_symbol']??'-'}',maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(fontWeight:isSel?FontWeight.w900:FontWeight.w600))),Expanded(child:Text(_num(x['ltp']).toStringAsFixed(2),textAlign:TextAlign.right)),Expanded(child:Text('${x['spread_pct']??'n/a'}',textAlign:TextAlign.right)),Expanded(child:Text('${x['score']??'-'}',textAlign:TextAlign.right))])));})])));}

class SwipeGuard extends StatefulWidget{const SwipeGuard({super.key,required this.label,required this.onTriggered});final String label;final Future<void> Function() onTriggered;@override State<SwipeGuard>createState()=>_SwipeGuardState();}
class _SwipeGuardState extends State<SwipeGuard>{double v=0;bool busy=false;@override Widget build(BuildContext context)=>Column(children:[Container(padding:const EdgeInsets.symmetric(horizontal:10),decoration:BoxDecoration(color:Theme.of(context).colorScheme.primaryContainer,borderRadius:BorderRadius.circular(18)),child:Row(children:[const Icon(Icons.swipe_right),Expanded(child:Slider(value:v,onChanged:busy?null:(n)=>setState(()=>v=n),onChangeEnd:(n)async{if(n>.92){setState(()=>busy=true);await widget.onTriggered();if(mounted)setState(()=>busy=false);}if(mounted)setState(()=>v=0);}),),Text(busy?'CHECKING…':widget.label,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w900))])),const SizedBox(height:4),const Text('Full swipe prepares the one-time server confirmation.',style:TextStyle(fontSize:11,color:Colors.black45))]);}
class TickCard extends StatelessWidget{const TickCard({super.key,required this.row,this.isHot=false});final Map<String,dynamic>row;final bool isHot;@override Widget build(BuildContext context){final p=_num(row['ltp']??row['last_traded_price']??row['lp']??row['price']);return RobotPanel(glow:isHot,padding:const EdgeInsets.symmetric(horizontal:14,vertical:8),child:ListTile(contentPadding:EdgeInsets.zero,leading:Container(width:42,height:42,decoration:BoxDecoration(shape:BoxShape.circle,color:const Color(0xffeaf9ff),border:Border.all(color:const Color(0xffa9ddeb))),child:Icon(isHot?Icons.bolt:Icons.show_chart,color:const Color(0xff008db5))),title:Text('${row['trading_symbol']??row['symbol']??row['instrument_token']??row['token']??'Live tick'}',style:const TextStyle(fontWeight:FontWeight.w900,color:Color(0xff17364f))),subtitle:Text('Broker stream${row['exchange_segment']!=null?' • ${row['exchange_segment']}':''}',style:const TextStyle(color:Color(0xff61788b))),trailing:Text(p>0?'\u20B9${p.toStringAsFixed(2)}':'LIVE',style:const TextStyle(fontWeight:FontWeight.w900,fontSize:17,color:Color(0xff087ca7)))));}}
class JsonPanel extends StatelessWidget{const JsonPanel({super.key,required this.title,required this.data});final String title;final dynamic data;@override Widget build(BuildContext context){String text;try{text=const JsonEncoder.withIndent('  ').convert(data);}catch(_){text='$data';}if(text.length>3000)text='${text.substring(0,3000)}\n…';return Padding(padding:const EdgeInsets.only(top:10),child:ExpansionTile(tilePadding:const EdgeInsets.symmetric(horizontal:12),collapsedBackgroundColor:Colors.white,backgroundColor:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14)),collapsedShape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14)),title:Text(title,style:const TextStyle(fontWeight:FontWeight.w800)),children:[Padding(padding:const EdgeInsets.all(12),child:SelectableText(text,style:const TextStyle(fontFamily:'monospace',fontSize:11))) ]));}}


class LoginDialog extends StatefulWidget{const LoginDialog({super.key,required this.api});final ApiService api;@override State<LoginDialog>createState()=>_LoginDialogState();}
class _LoginDialogState extends State<LoginDialog>{final c=TextEditingController();bool busy=false;String? err;@override void dispose(){c.dispose();super.dispose();}@override Widget build(BuildContext context)=>AlertDialog(title:const Text('Connect Kotak Neo'),content:Column(mainAxisSize:MainAxisSize.min,children:[const Text('Enter the current Kotak TOTP. MPIN and account identifiers stay on the backend environment, not in the app.',style:TextStyle(color:Colors.black54)),const SizedBox(height:12),TextField(controller:c,keyboardType:TextInputType.number,maxLength:8,decoration:const InputDecoration(labelText:'TOTP')),if(err!=null)Text(err!,style:const TextStyle(color:Colors.red))]),actions:[TextButton(onPressed:busy?null:()=>Navigator.pop(context),child:const Text('Cancel')),FilledButton(onPressed:busy?null:()async{if(c.text.trim().length<6)return;setState(()=>busy=true);try{await widget.api.postJson('/auth/login',{'totp':c.text.trim()});if(!mounted)return;Navigator.pop(context);ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Kotak connected')));}catch(e){if(mounted)setState((){err='$e';busy=false;});}},child:Text(busy?'Connecting…':'Connect'))]);}

class ExitPlanDialog extends StatefulWidget{const ExitPlanDialog({super.key,required this.api,required this.position});final ApiService api;final Map<String,dynamic>position;@override State<ExitPlanDialog>createState()=>_ExitPlanDialogState();}
class _ExitPlanDialogState extends State<ExitPlanDialog>{final sl=TextEditingController(),t1=TextEditingController(),t2=TextEditingController();bool auto=false,busy=false;String? msg;@override void dispose(){sl.dispose();t1.dispose();t2.dispose();super.dispose();}@override Widget build(BuildContext context)=>AlertDialog(title:Text('${widget.position['trading_symbol']??'Position'} levels'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:sl,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Stop loss')),const SizedBox(height:8),TextField(controller:t1,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Target 1')),const SizedBox(height:8),TextField(controller:t2,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Target 2')),SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Auto-exit'),subtitle:const Text('OFF by default'),value:auto,onChanged:(v)=>setState(()=>auto=v)),if(msg!=null)Notice(msg!)])),actions:[TextButton(onPressed:busy?null:()=>Navigator.pop(context),child:const Text('Cancel')),FilledButton(onPressed:busy?null:()async{setState(()=>busy=true);try{final body=<String,dynamic>{'position_key':'${widget.position['key']}','auto_exit':auto,'target1_fraction':0.5};if(_double(sl.text)>0)body['stop_loss']=_double(sl.text);if(_double(t1.text)>0)body['target1']=_double(t1.text);if(_double(t2.text)>0)body['target2']=_double(t2.text);await widget.api.postJson('/portfolio/exit-plan',body);if(!mounted)return;Navigator.pop(context);ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Exit plan saved')));}catch(e){if(mounted)setState((){msg='$e';busy=false;});}},child:const Text('Save'))]);}

class IndexStrip extends StatelessWidget{const IndexStrip({super.key,required this.items});final List<dynamic>items;@override Widget build(BuildContext context)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const SectionTitle('MARKET GRID'),const SizedBox(height:8),SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:items.map((v){final x=_map(v),tick=_map(x['tick']);final p=_num(tick['last_traded_price']??tick['ltp']??tick['price']);final live=p>0;return Container(width:152,margin:const EdgeInsets.only(right:9),padding:const EdgeInsets.all(13),decoration:BoxDecoration(gradient:const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Color(0xffffffff),Color(0xffedf8ff)]),borderRadius:BorderRadius.circular(17),border:Border.all(color:live?const Color(0xff95d9eb):const Color(0xffccd9e4)),boxShadow:live?const [BoxShadow(color:Color(0x3000a9d9),blurRadius:16)]:const []),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Text('${x['label']??'INDEX'}',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w900,letterSpacing:.4,color:Color(0xff36536a)))),Icon(Icons.circle,size:8,color:live?const Color(0xff17a95a):const Color(0xffa6b4bf))]),const SizedBox(height:7),Text(live?p.toStringAsFixed(2):'--',style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900,color:Color(0xff102f49))),const SizedBox(height:7),Container(height:2,decoration:const BoxDecoration(gradient:LinearGradient(colors:[Color(0x0000a9d9),Color(0xff00a9d9),Color(0x0000a9d9)]))) ]));}).toList()))]);} 

Map<String,dynamic> _map(dynamic v)=>v is Map<String,dynamic>?v:(v is Map?Map<String,dynamic>.from(v):<String,dynamic>{});
double _num(dynamic v){if(v is num)return v.toDouble();return double.tryParse('$v')??0;}
int _int(dynamic v){if(v is int)return v;if(v is num)return v.toInt();return int.tryParse('$v')??0;}
double _double(String s)=>double.tryParse(s.trim())??0;
String _money(double v,{bool sign=false})=>'${sign&&v>=0?'+':''}${NumberFormat.currency(locale:'en_IN',symbol:'\u20B9',decimalDigits:2).format(v)}';
List<Map<String,dynamic>> _flattenTickRows(dynamic payload){final out=<Map<String,dynamic>>[];void walk(dynamic x){if(x is Map){final m=Map<String,dynamic>.from(x);final keys=m.keys.map((e)=>e.toString()).toSet();if(keys.any((k)=>['ltp','last_traded_price','lp','price','instrument_token','token'].contains(k)))out.add(m);for(final v in m.values){if(v is Map||v is List)walk(v);}}else if(x is List){for(final v in x)walk(v);}}walk(payload);return out;}
