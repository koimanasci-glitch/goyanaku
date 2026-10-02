import 'package:flutter/material.dart';
import 'api.dart';

typedef ApiFactory = GoyanaApi Function(String address);
class GoyanaApp extends StatelessWidget {
  const GoyanaApp({super.key, this.apiFactory = HttpGoyanaApi.new});
  final ApiFactory apiFactory;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Goyana',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xffdb544b)),
      scaffoldBackgroundColor: const Color(0xfff5f6f8),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true, fillColor: Colors.white, border: OutlineInputBorder()),
    ),
    home: AccountPage(apiFactory: apiFactory),
  );
}
class AccountPage extends StatefulWidget {
  const AccountPage({super.key, required this.apiFactory});
  final ApiFactory apiFactory;
  @override
  State<AccountPage> createState() => _AccountPageState();
}
class _AccountPageState extends State<AccountPage> {
  final _form = GlobalKey<FormState>();
  final _server = TextEditingController(
      text: const String.fromEnvironment('GOYANA_API_URL'));
  final _email = TextEditingController();
  final _password = TextEditingController();
  GoyanaApi? _api;
  Map<String, dynamic>? _profile;
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _server.dispose(); _email.dispose(); _password.dispose(); super.dispose();
  }
  Future<void> _login() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      final api = widget.apiFactory(_server.text);
      await api.login(_email.text, _password.text);
      _password.clear();
      _api = api;
      final profile = await api.profile();
      if (mounted) setState(() => _profile = profile);
    } on ApiFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Data server belum dapat ditampilkan.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
  Future<void> _refresh() async {
    setState(() { _busy = true; _error = null; });
    try {
      final profile = await _api!.profile();
      if (mounted) setState(() => _profile = profile);
    } on ApiFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Data belum dapat diperbarui.');
    } finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _logout() async {
    setState(() => _busy = true);
    String? warning;
    try { await _api?.logout(); } catch (_) {
      warning = 'Sesi di HP ditutup. Pencabutan di server belum terkonfirmasi; token kedaluwarsa paling lama 24 jam.';
    }
    if (mounted) setState(() {
      _api = null; _profile = null; _password.clear(); _busy = false; _error = warning;
    });
  }
  Widget _card(Widget child) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: Colors.white,
      border: Border.all(color: const Color(0xffe2e6ea)),
      borderRadius: BorderRadius.circular(16)),
    child: child,
  );
  Widget _loginForm() => Form(key: _form, child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Masuk ke usaha', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      const Text('Gunakan akun owner yang sudah terdaftar di web Goyana.'),
      const SizedBox(height: 24),
      TextFormField(controller: _server, enabled: !_busy,
        decoration: const InputDecoration(labelText: 'Alamat server HTTPS'),
        keyboardType: TextInputType.url, autocorrect: false,
        validator: (value) => value == null || value.trim().isEmpty ? 'Isi alamat server uji.' : null),
      const SizedBox(height: 16),
      TextFormField(controller: _email, enabled: !_busy,
        decoration: const InputDecoration(labelText: 'Email'),
        keyboardType: TextInputType.emailAddress, autocorrect: false,
        validator: (value) => value == null || !value.contains('@') ? 'Isi email akun.' : null),
      const SizedBox(height: 16),
      TextFormField(controller: _password, enabled: !_busy, obscureText: true,
        enableSuggestions: false, autocorrect: false,
        decoration: const InputDecoration(labelText: 'Password'),
        validator: (value) => value == null || value.isEmpty ? 'Isi password.' : null),
      const SizedBox(height: 20),
      SizedBox(width: double.infinity, child: FilledButton(
        onPressed: _busy ? null : _login, child: const Text('Masuk'))),
    ],
  ));
  Widget _dashboard() {
    final business = _profile!['business'] as Map<String, dynamic>;
    final access = _profile!['access'] as Map<String, dynamic>;
    final outlets = _profile!['outlets'] as List<dynamic>;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(business['name'] as String, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 16),
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('PAKET USAHA'), const SizedBox(height: 8),
        Text(access['package'] as String? ?? 'Berakhir',
          style: Theme.of(context).textTheme.titleLarge),
        Text(access['read_only'] == true ? 'Mode baca saja' : 'Hak dasar aktif'),
        Text('Sumber: ${access['source']}'),
      ])),
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('OUTLET'),
        for (final outlet in outlets) ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.storefront_outlined),
          title: Text(outlet['name'] as String)),
      ])),
      Wrap(spacing: 12, runSpacing: 12, children: [
        FilledButton.icon(onPressed: _busy ? null : _refresh,
          icon: const Icon(Icons.refresh), label: const Text('Perbarui')),
        OutlinedButton(onPressed: _busy ? null : _logout, child: const Text('Keluar')),
      ]),
    ]);
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Goyana'),
      backgroundColor: Colors.white, surfaceTintColor: Colors.white),
    body: SafeArea(child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: ListView(padding: const EdgeInsets.all(20), children: [
        _card(const Text('Versi fondasi Flutter · akun dan paket. Transaksi, offline dan perangkat belum dihubungkan.')),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        if (_profile == null) _card(_loginForm()) else _dashboard(),
      ]),
    ))),
  );
}
