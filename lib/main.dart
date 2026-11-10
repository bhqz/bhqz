import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_vless/flutter_vless.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/v2board.dart';

void main() => runApp(const FnyunApp());

class FnyunApp extends StatelessWidget {
  const FnyunApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Fnyun', debugShowCheckedModeBanner: false,
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF246BFD), brightness: Brightness.light), useMaterial3: true, scaffoldBackgroundColor: const Color(0xFFF7F8FA)),
    home: const Gate(),
  );
}

class Gate extends StatefulWidget { const Gate({super.key}); @override State<Gate> createState() => _GateState(); }
class _GateState extends State<Gate> {
  final store = const FlutterSecureStorage();
  @override void initState() { super.initState(); _restore(); }
  Future<void> _restore() async {
    try {
      final auth = await store.read(key: 'auth_data');
      if (auth != null && mounted) {
        V2Board.instance.authData = auth;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
        return;
      }
    } catch (_) {}
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthPage()));
  }
  @override Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class AuthPage extends StatefulWidget { const AuthPage({super.key}); @override State<AuthPage> createState() => _AuthPageState(); }
class _AuthPageState extends State<AuthPage> {
  final email = TextEditingController(), password = TextEditingController();
  final secure = const FlutterSecureStorage();
  bool register = false, busy = false, obscure = true;
  String? error;
  Future<void> submit() async {
    final e = email.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(e)) { setState(() => error = '请输入有效邮箱地址'); return; }
    if (password.text.length < 8) { setState(() => error = '密码至少需要 8 位'); return; }
    setState(() { busy = true; error = null; });
    try {
      await V2Board.instance.findAvailableDomain();
      final data = register ? await V2Board.instance.register(e, password.text) : await V2Board.instance.login(e, password.text);
      final auth = data['auth_data']?.toString();
      if (auth == null || auth.isEmpty) throw Exception('登录响应缺少 auth_data');
      V2Board.instance.authData = auth;
      await secure.write(key: 'auth_data', value: auth);
      await secure.write(key: 'user_token', value: data['token']?.toString() ?? '');
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
    } catch (e) { setState(() => error = e.toString().replaceFirst('Exception: ', '')); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(28), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 390), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const Icon(Icons.bolt_rounded, size: 54, color: Color(0xFF246BFD)), const SizedBox(height: 12), const Text('Fnyun', textAlign: TextAlign.center, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700)), const SizedBox(height: 8), Text(register ? '创建账号' : '欢迎回来', textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)), const SizedBox(height: 32),
    TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: '邮箱', prefixIcon: Icon(Icons.mail_outline), border: OutlineInputBorder())), const SizedBox(height: 14),
    TextField(controller: password, obscureText: obscure, decoration: InputDecoration(labelText: '密码（至少 8 位）', prefixIcon: const Icon(Icons.lock_outline), border: const OutlineInputBorder(), suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined), onPressed: () => setState(() => obscure = !obscure)))),
    if (error != null) ...[const SizedBox(height: 12), Text(error!, style: const TextStyle(color: Colors.red))], const SizedBox(height: 22),
    FilledButton(onPressed: busy ? null : submit, style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)), child: busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(register ? '注册' : '登录')),
    TextButton(onPressed: busy ? null : () => setState(() { register = !register; error = null; }), child: Text(register ? '已有账号？返回登录' : '没有账号？立即注册')),
  ])))));
}

class NodeItem { NodeItem(this.parsed, this.config, this.name); final FlutterVlessURL parsed; final String config; final String name; int? delay; }

class HomePage extends StatefulWidget { const HomePage({super.key}); @override State<HomePage> createState() => _HomePageState(); }
class _HomePageState extends State<HomePage> {
  final secure = const FlutterSecureStorage();
  late final FlutterVless core = FlutterVless(onStatusChanged: (s) { if (mounted) setState(() => status = s.state); });
  final List<NodeItem> nodes = [];
  String status = 'DISCONNECTED', message = '正在同步订阅…';
  bool busy = false;
  int selected = -1;
  bool get connected => status.toUpperCase() == 'CONNECTED';
  @override void initState() { super.initState(); _refresh(); }
  Future<void> _refresh() async {
    setState(() { busy = true; message = '正在更新节点…'; });
    try {
      final sub = await V2Board.instance.getSubscribe();
      final url = sub['subscribe_url']?.toString();
      if (url == null || url.isEmpty) throw Exception('账号没有可用订阅地址');
      final content = await V2Board.instance.fetchSubscription(url);
      final parsed = FlutterVless.parseMany(content);
      if (parsed.isEmpty) throw Exception('订阅中没有可识别节点');
      nodes..clear();
      for (final p in parsed) { nodes.add(NodeItem(p, p.getFullConfiguration(), p.remark.isEmpty ? '未命名节点' : p.remark)); }
      if (selected >= nodes.length) selected = -1;
      if (mounted) setState(() => message = '已更新 ${nodes.length} 个节点');
    } catch (e) { if (mounted) setState(() => message = e.toString().replaceFirst('Exception: ', '')); }
    finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> _testAll() async {
    if (nodes.isEmpty) return;
    setState(() { busy = true; message = '正在测试节点延迟…'; });
    for (final n in nodes) {
      try { n.delay = await core.getServerDelay(config: n.config, url: 'https://www.gstatic.com/generate_204'); }
      catch (_) { n.delay = 999999; }
      if (mounted) setState(() {});
    }
    nodes.sort((a,b) => (a.delay ?? 999999).compareTo(b.delay ?? 999999));
    selected = 0;
    if (mounted) setState(() { message = '测速完成，已选最快节点'; busy = false; });
  }
  Future<void> _connect() async {
    if (nodes.isEmpty) { await _refresh(); if (nodes.isEmpty) return; }
    setState(() => busy = true);
    try {
      if (selected < 0 || selected >= nodes.length) await _testAll();
      if (nodes.isEmpty) throw Exception('没有可连接节点');
      await core.initializeVless(providerBundleIdentifier: 'com.fnyun.client', groupIdentifier: 'group.com.fnyun.client');
      final ok = await core.requestPermission();
      if (!ok) throw Exception('未获得 VPN 权限');
      final node = nodes[selected < 0 ? 0 : selected];
      await core.startVless(remark: node.name, config: node.config);
      if (mounted) setState(() => message = '已连接：${node.name}');
    } catch (e) { if (mounted) setState(() => message = e.toString().replaceFirst('Exception: ', '')); }
    finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> _disconnect() async { try { await core.stopVless(); } catch (e) { setState(() => message = e.toString()); } }
  Future<void> _logout() async { await _disconnect(); await secure.delete(key: 'auth_data'); await secure.delete(key: 'user_token'); V2Board.instance.authData = null; if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const AuthPage()), (_) => false); }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Fnyun'), actions: [IconButton(onPressed: busy ? null : _refresh, icon: const Icon(Icons.refresh)), IconButton(onPressed: _logout, icon: const Icon(Icons.logout))]), body: SafeArea(child: Column(children: [
    const SizedBox(height: 28), Container(width: 132, height: 132, decoration: BoxDecoration(color: connected ? Colors.green.withOpacity(.10) : const Color(0xFFEAF0FF), shape: BoxShape.circle), child: Icon(connected ? Icons.shield : Icons.shield_outlined, size: 62, color: connected ? Colors.green : const Color(0xFF246BFD))), const SizedBox(height: 14), Text(connected ? '已连接' : '未连接', style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w600)), const SizedBox(height: 6), Text(message, style: const TextStyle(color: Colors.black54), textAlign: TextAlign.center), const SizedBox(height: 22),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: FilledButton.icon(onPressed: busy ? null : (connected ? _disconnect : _connect), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)), icon: Icon(connected ? Icons.stop : Icons.power_settings_new), label: Text(connected ? '断开连接' : '连接'))),
    const SizedBox(height: 24), Padding(padding: const EdgeInsets.symmetric(horizontal: 22), child: Row(children: [const Expanded(child: Text('节点列表', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600))), TextButton.icon(onPressed: busy || nodes.isEmpty ? null : _testAll, icon: const Icon(Icons.speed, size: 18), label: const Text('测速并选最快'))])),
    Expanded(child: nodes.isEmpty ? Center(child: busy ? const CircularProgressIndicator() : const Text('暂无节点')) : ListView.separated(padding: const EdgeInsets.fromLTRB(16, 0, 16, 20), itemCount: nodes.length, separatorBuilder: (_,__) => const SizedBox(height: 8), itemBuilder: (_,i) { final n = nodes[i]; return Material(color: Colors.white, borderRadius: BorderRadius.circular(14), child: ListTile(onTap: () => setState(() => selected = i), leading: Icon(selected == i ? Icons.radio_button_checked : Icons.radio_button_off, color: selected == i ? const Color(0xFF246BFD) : Colors.black38), title: Text(n.name, maxLines: 1, overflow: TextOverflow.ellipsis), trailing: Text(n.delay == null ? '未测速' : n.delay! >= 999999 ? '超时' : '${n.delay} ms', style: TextStyle(color: n.delay == null ? Colors.black45 : n.delay! >= 999999 ? Colors.red : Colors.green, fontWeight: FontWeight.w500)))); })),
  ])));
}
