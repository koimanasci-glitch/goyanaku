import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../native/common.dart';
import 'device_store.dart';
import 'automation_tile.dart';

/// Not registered in PureShell yet: mounting awaits Paduka's instruction.
class WhatsAppDevicesPage extends StatefulWidget {
  const WhatsAppDevicesPage({super.key, required this.store, this.onBuySlots});
  final WaDeviceStore store;
  final VoidCallback? onBuySlots;
  @override
  State<WhatsAppDevicesPage> createState() => _WhatsAppDevicesPageState();
}

class _WhatsAppDevicesPageState extends State<WhatsAppDevicesPage> {
  bool busy = false;
  String? notice;
  WaDeviceStore get store => widget.store;
  @override
  void initState() {
    super.initState();
    _run(() async {
      await store.load();
      if (store.request != null) await store.refresh();
    });
  }

  Future<void> _run(Future<void> Function() work) async {
    if (busy) return;
    setState(() {
      busy = true;
      notice = null;
    });
    try {
      await work();
    } catch (e) {
      if (mounted) {
        setState(
          () => notice = e is WaFailure
              ? e.message
              : 'Proses belum berhasil. Periksa koneksi lalu coba lagi.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String outletName(WaDevice d) =>
      store.outlets.where((o) => o.key == d.outletKey).firstOrNull?.name ??
      'Outlet belum dipetakan';
  String statusName(WaDevice d) => switch (d.status) {
    'draft' => 'Draf di perangkat ini',
    'connected' => 'Terhubung (hasil pemeriksaan terakhir)',
    'pairing' => 'Menunggu pemasangan',
    'disconnected' => 'Belum terhubung',
    _ => 'Status belum diperiksa',
  };
  Future<void> edit([WaDevice? d]) async {
    if (store.outlets.isEmpty) {
      setState(() => notice = 'Lengkapi outlet utama terlebih dahulu.');
      return;
    }
    final result =
        await _showWaDialog<({String name, String phone, String outlet})>(
          context: context,
          builder: (_) => _DeviceForm(outlets: store.outlets, device: d),
        );
    if (result == null || !mounted) return;
    await _run(
      () => store.save(
        id: d?.id,
        name: result.name,
        phone: result.phone,
        outletKey: result.outlet,
      ),
    );
  }

  Future<void> pair(WaDevice d) async {
    final method = await _showWaDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('HUBUNGKAN WHATSAPP', style: gText(16, w: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Pilih cara menautkan nomor ${d.phone}.', style: gText(13)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.qr_code, color: gBrand),
              title: const Text('Scan QR'),
              onTap: () => Navigator.pop(context, 'qr'),
            ),
            ListTile(
              leading: const Icon(Icons.pin_outlined, color: gBrand),
              title: const Text('Kode Pemasangan'),
              onTap: () => Navigator.pop(context, 'code'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
        ],
      ),
    );
    if (method == null || !mounted) return;
    WaPairing? pairing;
    await _run(() async {
      pairing = await store.pair(d.id, method);
    });
    if (!mounted || pairing == null) return;
    await _showWaDialog<void>(
      context: context,
      builder: (_) => _PairingDialog(pairing: pairing!, clock: store.clock),
    );
    // A QR/code being displayed never changes the status to connected.
  }

  Future<void> remove(WaDevice d) async {
    final yes = await _showWaDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus perangkat?'),
        content: Text(
          d.registered
              ? 'Sambungan ${d.name} akan diputus. Jika server gagal, perangkat tetap disimpan.'
              : 'Hapus draf ${d.name} dari perangkat ini?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (yes == true && mounted) await _run(() => store.remove(d.id));
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final scoped = base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: gBrand,
        primary: gBrand,
        surface: Colors.white,
      ),
      textTheme: base.textTheme.apply(fontFamily: gFont),
      scaffoldBackgroundColor: Colors.white,
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xffdfe2e7)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: gBrand),
        ),
      ),
    );
    return Theme(
      data: scoped,
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.white,
            foregroundColor: gInk,
            title: Text(
              'PERANGKAT WHATSAPP',
              style: gText(16, w: FontWeight.w600),
            ),
            actions: [
              IconButton(
                tooltip: 'Perbarui daftar',
                onPressed: busy ? null : () => _run(store.refresh),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Hubungkan nomor WhatsApp laundry Anda.',
                  style: gText(13, c: const Color(0xff6b7280)),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xfffff2ee),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        store.slotLimit == null
                            ? 'Kuota diperiksa saat terhubung ke server'
                            : 'Slot WhatsApp: ${store.slotsUsed} / ${store.slotLimit}',
                        style: gText(13, w: FontWeight.w600),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Draf belum memakai slot. Penambahan cabang tidak menambah slot WhatsApp.',
                        style: gText(12),
                      ),
                      if (widget.onBuySlots != null)
                        TextButton(
                          onPressed: busy ? null : widget.onBuySlots,
                          child: const Text('Tambah Slot WhatsApp'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: busy ? null : () => edit(),
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah Perangkat'),
                ),
                if (busy)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: LinearProgressIndicator(),
                  ),
                if (notice != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(notice!, style: gText(12, c: gBrand)),
                  ),
                if (store.devices.isEmpty && !busy)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Belum ada perangkat. Nama, nomor, dan outlet bisa disimpan sebagai draf tanpa koneksi server.',
                      style: gText(13),
                    ),
                  ),
                for (final d in store.devices)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xffe5e7eb)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.name, style: gText(15, w: FontWeight.w600)),
                        Text(
                          '+${d.phone} · ${outletName(d)}',
                          style: gText(12),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          statusName(d),
                          style: gText(12, c: const Color(0xff6b7280)),
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: busy ? null : () => pair(d),
                              child: const Text('Hubungkan'),
                            ),
                            TextButton(
                              onPressed: busy ? null : () => edit(d),
                              child: const Text('Edit'),
                            ),
                            TextButton(
                              onPressed: busy ? null : () => remove(d),
                              child: const Text('Hapus'),
                            ),
                            if (d.registered)
                              TextButton(
                                onPressed: busy
                                    ? null
                                    : () =>
                                          _run(() => store.refreshDevice(d.id)),
                                child: const Text('Periksa Status'),
                              ),
                          ],
                        ),
                        const Divider(),
                        WaStatusAutomationTile(
                          value: d.replyStatus,
                          allowed: store.statusAllowed,
                          busy: busy || !d.registered,
                          onChanged: (v) => _run(
                            () => store.automation(
                              d.id,
                              status: v,
                              services: d.replyServices,
                            ),
                          ),
                        ),
                        if (!store.statusAllowed)
                          Text(
                            'Hak fitur mengikuti pengaturan paket di server.',
                            style: gText(11, c: const Color(0xff6b7280)),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeviceForm extends StatefulWidget {
  const _DeviceForm({required this.outlets, this.device});
  final List<WaOutlet> outlets;
  final WaDevice? device;
  @override
  State<_DeviceForm> createState() => _DeviceFormState();
}

class _DeviceFormState extends State<_DeviceForm> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.device?.name ?? '');
  late final phone = TextEditingController(text: widget.device?.phone ?? '');
  late String? outlet =
      widget.outlets.any((o) => o.key == widget.device?.outletKey)
      ? widget.device!.outletKey
      : widget.outlets.length == 1
      ? widget.outlets.first.key
      : null;
  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.device == null ? 'TAMBAH PERANGKAT' : 'EDIT PERANGKAT',
      style: gText(16, w: FontWeight.w600),
    ),
    content: SizedBox(
      width: 360,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                maxLength: 80,
                style: gText(13),
                decoration: const InputDecoration(labelText: 'Nama perangkat'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Isi nama perangkat' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phone,
                keyboardType: TextInputType.phone,
                style: gText(13),
                decoration: const InputDecoration(
                  labelText: 'Nomor WhatsApp',
                  hintText: '08xxxxxxxxxx',
                ),
                validator: (v) {
                  try {
                    normalizeWaPhone(v ?? '');
                    return null;
                  } on WaFailure catch (e) {
                    return e.message;
                  }
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: outlet,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Outlet'),
                items: widget.outlets
                    .map(
                      (o) => DropdownMenuItem(
                        value: o.key,
                        child: Text(
                          o.name,
                          overflow: TextOverflow.ellipsis,
                          style: gText(13),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => outlet = v),
                validator: (v) => v == null ? 'Pilih outlet' : null,
              ),
              const SizedBox(height: 12),
              Text(
                widget.device?.registered == true
                    ? 'Perubahan perangkat server memerlukan koneksi.'
                    : 'Simpan dahulu sebagai draf. QR/kode diminta saat Hubungkan.',
                style: gText(11, c: const Color(0xff6b7280)),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      FilledButton(
        onPressed: () {
          if (form.currentState!.validate()) {
            Navigator.pop(context, (
              name: name.text,
              phone: phone.text,
              outlet: outlet!,
            ));
          }
        },
        child: const Text('Simpan'),
      ),
    ],
  );
}

class _PairingDialog extends StatefulWidget {
  const _PairingDialog({required this.pairing, required this.clock});
  final WaPairing pairing;
  final DateTime Function() clock;
  @override
  State<_PairingDialog> createState() => _PairingDialogState();
}

class _PairingDialogState extends State<_PairingDialog>
    with WidgetsBindingObserver {
  Timer? timer;
  bool hidden = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && mounted) {
      setState(() => hidden = true);
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expired = hidden || !widget.pairing.expiresAt.isAfter(widget.clock());
    return AlertDialog(
      title: Text(
        widget.pairing.kind == 'qr' ? 'SCAN QR WHATSAPP' : 'KODE PEMASANGAN',
        style: gText(16, w: FontWeight.w600),
      ),
      content: SizedBox(
        width: 260,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (expired)
              Text(
                'QR/kode sudah ditutup atau kedaluwarsa. Tutup lalu minta ulang.',
                style: gText(13),
              )
            else if (widget.pairing.kind == 'qr')
              QrImageView(
                data: widget.pairing.value,
                size: 230,
                backgroundColor: Colors.white,
              )
            else
              SelectableText(
                widget.pairing.value,
                style: gText(24, w: FontWeight.w600, c: gBrand),
              ),
            const SizedBox(height: 12),
            Text(
              'Pasangkan melalui menu Perangkat Tertaut di WhatsApp. Setelah selesai, tekan Periksa Status pada daftar perangkat.',
              style: gText(12),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Tutup'),
        ),
      ],
    );
  }
}

Future<T?> _showWaDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  final base = Theme.of(context);
  final theme = base.copyWith(
    colorScheme: ColorScheme.fromSeed(
      seedColor: gBrand,
      primary: gBrand,
      surface: Colors.white,
    ),
    textTheme: base.textTheme.apply(fontFamily: gFont),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: gBrand),
      ),
    ),
  );
  return showDialog<T>(
    context: context,
    builder: (ctx) => Theme(
      data: theme,
      child: Builder(builder: builder),
    ),
  );
}
