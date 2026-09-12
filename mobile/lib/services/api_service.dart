import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

class ApiService {
  ApiService(this.baseUrl);
  String baseUrl;
  static const String appToken = String.fromEnvironment('APP_API_TOKEN', defaultValue: '');
  Map<String,String> get _headers => {'content-type':'application/json', if(appToken.isNotEmpty) 'authorization':'Bearer $appToken'};
  Uri _uri(String path, [Map<String,String>? query]) => Uri.parse('$baseUrl$path').replace(queryParameters: query);

  Future<dynamic> getAny(String path, {Map<String,String>? query}) async {
    final r = await http.get(_uri(path, query), headers:_headers).timeout(const Duration(seconds: 8));
    if (r.statusCode < 200 || r.statusCode >= 300) throw Exception(_friendlyError(r.statusCode,r.body));
    return r.body.isEmpty ? <String,dynamic>{} : jsonDecode(r.body);
  }
  Future<Map<String,dynamic>> getJson(String path, {Map<String,String>? query}) async {
    final v = await getAny(path, query: query);
    return v is Map<String,dynamic> ? v : {'data': v};
  }
  Future<dynamic> postAny(String path, Map<String,dynamic> body, {Duration timeout = const Duration(seconds: 12)}) async {
    final r = await http.post(_uri(path), headers:_headers, body:jsonEncode(body)).timeout(timeout);
    final v = r.body.isEmpty ? <String,dynamic>{} : jsonDecode(r.body);
    if (r.statusCode < 200 || r.statusCode >= 300) throw Exception(_friendlyError(r.statusCode,r.body));
    return v;
  }
  Future<Map<String,dynamic>> postJson(String path, Map<String,dynamic> body, {Duration timeout = const Duration(seconds: 12)}) async {
    final v = await postAny(path, body, timeout: timeout);
    return v is Map<String,dynamic> ? v : {'data': v};
  }

  String _friendlyError(int status,String body){
    final lower=body.toLowerCase();
    if(status==401&&(lower.contains('kotak_session_expired')||lower.contains('invalid session token')||lower.contains('login required'))){
      return 'SESSION EXPIRED • Login to Kotak Neo again';
    }
    if(status==401&&lower.contains('invalid app token')) return 'APP AUTH FAILED • Check production app token';
    try{final v=jsonDecode(body);if(v is Map&&v['detail']!=null)return '${v['detail']}';}catch(_){ }
    return 'Request failed ($status)';
  }

  Stream<Map<String,dynamic>> reconnectingTicks({Duration retry = const Duration(seconds: 2)}) async* {
    while (true) {
      WebSocketChannel? c;
      try {
        final ws = baseUrl.replaceFirst(RegExp(r'^http'), 'ws');
        final uri = Uri.parse('$ws/ws/ticks').replace(queryParameters: appToken.isEmpty ? null : {'token': appToken});
        c = WebSocketChannel.connect(uri);
        await c.ready.timeout(const Duration(seconds: 8));
        yield {'_connection':'connected'};
        await for (final e in c.stream) {
          final v=jsonDecode(e as String);
          yield v is Map<String,dynamic>?v:{'data':v};
        }
      } catch (e) {
        yield {'_connection':'disconnected','error':'$e'};
      } finally {
        try { await c?.sink.close(); } catch (_) {}
      }
      await Future<void>.delayed(retry);
    }
  }
}
