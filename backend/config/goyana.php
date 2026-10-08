<?php

/*
 | GOYANA business rules that the server enforces.
 | Source: GOYANA-SISTEM-PUSAT.md §5 (katalog) and GOYANA-ROADMAP.md §6/§37.
 */
return [

    // Trial: Basic for 2 months, then READ-ONLY until a paid package is active
    // (keputusan pengguna 2 Oktober 2026 — tidak ada paket gratis yang tetap bisa dipakai).
    'trial' => ['package' => 'Basic', 'months' => 2],

    // branches = cabang di luar 1 outlet pusat. Basic: 1 pusat + 1 cabang (ditegaskan pengguna 2 Oktober 2026).
    'packages' => [
        'Basic' => ['price' => 30000, 'branches' => 1, 'rank' => 1, 'cashier_devices' => 2],
        'Silver' => ['price' => 65000, 'branches' => 2, 'rank' => 2, 'cashier_devices' => 3],
        'Gold' => ['price' => 100000, 'branches' => 3, 'rank' => 3, 'cashier_devices' => 4],
        'Platinum' => ['price' => 350000, 'branches' => 5, 'rank' => 4, 'cashier_devices' => 5],
    ],

    // Perangkat kasir per outlet (termasuk pusat) mengikuti paket (keputusan pengguna 8 Oktober 2026:
    // Trial/Basic 2, Silver 3, Gold 4, Platinum 5). Angka di bawah dipakai bila paket tidak menyebutnya.
    'cashier_devices_per_outlet' => 2,

    // Divisi akun administrator pusat. Area: clients (lihat client), grants (paket sementara), billing (langganan,
    // saldo AI, tambah client), assist, support (tiket, FAQ), marketing, reports, system, settings, audit, admins.
    'admin_divisions' => [
        'owner' => ['label' => 'Pemilik', 'areas' => ['*']],
        'marketing' => ['label' => 'Marketing', 'areas' => ['marketing', 'reports']],
        'cs' => ['label' => 'CS / Bantuan', 'areas' => ['clients', 'grants', 'assist', 'support']],
        'teknis' => ['label' => 'Teknis', 'areas' => ['clients', 'system', 'settings', 'audit']],
    ],

    // Masuk dengan Google (pemilik): Client ID OAuth yang diterima server, dipisah koma di GOYANA_GOOGLE_CLIENT_IDS.
    // Kosong = masuk Google dimatikan. Client ID bukan rahasia, tetapi tetap diatur di .env server, bukan di repo.
    'google' => ['client_ids' => array_values(array_filter(array_map('trim', explode(',', (string) env('GOYANA_GOOGLE_CLIENT_IDS', '')))))],

    // Email pemilik yang usahanya selalu mendapat paket tertinggi tanpa masa berakhir (akun uji pemilik GOYANA).
    // Diatur di .env server (GOYANA_FULL_ACCESS_EMAILS, dipisah koma), tidak pernah di dalam APK.
    'full_access' => [
        'emails' => array_values(array_filter(array_map(fn ($e) => mb_strtolower(trim($e)), explode(',', (string) env('GOYANA_FULL_ACCESS_EMAILS', ''))))),
        'package' => 'Platinum',
    ],

    // Sesi aplikasi pemilik: sekali masuk tetap masuk; diperpanjang setiap aplikasi dibuka (keputusan pengguna 8 Oktober 2026).
    'session' => ['owner_days' => 90],

    // Login pegawai (kasir, produksi, kurir) memakai nomor HP + PIN (keputusan pengguna 8 Oktober 2026).
    // Owner dan admin pusat tetap email + password.
    'pin' => [
        'length' => 6,
        'max_attempts' => 5,     // salah berturut-turut sebelum akun dikunci sementara
        'lock_minutes' => 15,
        'session_days' => 30,    // HP pegawai tetap masuk; pencabutan akses tetap berlaku seketika
    ],

    'roles' => [
        'owner' => ['label' => 'Owner', 'permissions' => ['*']],
        'kasir' => ['label' => 'Kasir', 'permissions' => [
            'orders.create', 'orders.update', 'orders.status', 'payments.receive',
            'discounts.limited', 'customers.manage', 'courier.assign', 'cash.manage',
        ]],
        'produksi' => ['label' => 'Pegawai', 'permissions' => ['orders.status', 'stock.use']],
        'kurir' => ['label' => 'Kurir', 'permissions' => ['courier.tasks']],
        'manager' => ['label' => 'Admin Outlet', 'permissions' => [
            'orders.create', 'orders.update', 'orders.status', 'orders.cancel',
            'payments.receive', 'payments.refund', 'discounts.any', 'prices.edit',
            'customers.manage', 'stock.manage', 'courier.assign', 'cash.manage', 'reports.view',
        ]],
    ],

    // Default pengaturan platform; administrator mengubahnya di /admin/settings (GOYANA-SISTEM-PUSAT.md §42–§47).
    'settings' => [
        'ai_margin_percent' => 25,        // untung di atas modal AI (§44)
        'ai_min_topup' => 50000,          // rupiah
        'fx_cushion_percent' => 2,        // cadangan kurs USD→IDR
        'ai_daily_budget_usd' => 5,       // batas biaya AI CS pusat per hari
        'ai_model_primary' => '',         // id model OpenRouter, dipilih admin dari daftar harga harian
        'ai_model_fallback' => '',
        'bot_pause_minutes' => 15,        // bot diam setelah kasir membalas manual (§47)
        'msg_welcome' => true,            // pesan otomatis hemat (§42B)
        'msg_expiry_reminder' => true,
        'msg_expired' => true,
        'msg_payment' => true,
        'cs_whatsapp' => '',              // nomor WA CS pusat, contoh 62812xxxx
        // WA blast divisi marketing (keputusan pengguna 8 Oktober 2026: "digilir, sehari jangan banyak-banyak").
        // Titik awal yang hati-hati; WhatsApp tidak mengumumkan batasnya, jadi disesuaikan dari hasil nyata.
        'blast_start_per_day' => 20,      // jatah per nomor pengirim pada minggu pertama
        'blast_step_per_week' => 10,      // kenaikan jatah harian tiap minggu
        'blast_max_per_day' => 80,        // batas atas jatah harian per nomor
        'blast_gap_min' => 2,             // jeda acak antar pesan (menit)
        'blast_gap_max' => 6,
        'blast_hour_start' => 9,          // jam kirim WIB
        'blast_hour_end' => 17,
        'blast_sunday' => false,          // Minggu libur
        'blast_followup_days' => 5,       // jarak pesan tindak lanjut dari pesan pembuka
        'blast_recontact_days' => 30,     // satu nomor tidak dikirimi kampanye baru lebih cepat dari ini
        'blast_fail_stop' => 5,           // gagal berturut-turut sebelum nomor pengirim dihentikan
    ],

    // Sumber kurs & harga model harian (§44). Bisa diganti tanpa ubah kode.
    'fx_url' => env('GOYANA_FX_URL', 'https://open.er-api.com/v6/latest/USD'),
    'ai_models_url' => env('GOYANA_AI_MODELS_URL', 'https://openrouter.ai/api/v1/models'),

    // Admin pusat wajib OTP (aplikasi authenticator). Matikan hanya untuk pengembangan lokal.
    'admin_mfa' => env('GOYANA_ADMIN_MFA', true),

    // Wajibkan verifikasi email owner. Aktifkan setelah SMTP/email pengirim produksi siap.
    'require_email_verification' => env('GOYANA_REQUIRE_EMAIL_VERIFICATION', false),

    /*
     | Sync collections from the Android app. write = any of these permissions may change it,
     | read = any of these may download it ('*' = every role of the business).
     | scope outlet = record belongs to one outlet (staff only see their outlet); business = shared.
     | transactional = writing it uses a cashier device slot (max 2 per outlet).
     */
    'sync' => [
        'max_changes' => 200,
        'max_record_bytes' => 400000,
        'collections' => [
            'orders' => ['scope' => 'outlet', 'transactional' => true, 'read' => ['*'],
                'write' => ['orders.create', 'orders.update', 'orders.status', 'payments.receive', 'courier.tasks']],
            'kas' => ['scope' => 'outlet', 'transactional' => true, 'read' => ['cash.manage'], 'write' => ['cash.manage']],
            'deposits' => ['scope' => 'business', 'transactional' => true, 'read' => ['payments.receive'], 'write' => ['payments.receive']],
            // Kurir dan produksi tidak menerima database pelanggan; data pelanggan yang mereka perlukan ada di tugasnya.
            'customers' => ['scope' => 'business', 'read' => ['customers.manage', 'orders.create'], 'write' => ['customers.manage', 'orders.create']],
            // Tugas penjemputan sebelum transaksi dibuat (dari kasir, owner, atau chatbot).
            'pickups' => ['scope' => 'outlet', 'read' => ['courier.assign', 'courier.tasks'], 'write' => ['courier.assign', 'courier.tasks']],
            'services' => ['scope' => 'business', 'read' => ['*'], 'write' => ['prices.edit']],
            // Setelan usaha. Kunci yang dikirim Mode Murni (mobile/lib/pure/server_sync.dart): tarif antar-jemput, QRIS,
            // parfum, durasi layanan, dan "goyana-pure-shared" (diskon, kategori pengeluaran, izin kasir, rekening,
            // status otomatis, voucher, templat nota). Setelan milik HP (printer, PIN) tidak pernah dikirim.
            'settings' => ['scope' => 'business', 'read' => ['*'], 'write' => ['prices.edit']],
            'outlet_profiles' => ['scope' => 'business', 'read' => ['*'], 'write' => ['owner']],
            // CRM Mode Murni (goyana-crm203), dipecah per kunci supaya dua HP tidak saling menimpa:
            // "rules" (aturan poin dan pengingat), "voucher:<kode>", "redeemed:<pelanggan>", "reminded:<nota>".
            // Kasir hanya boleh menandai voucher terpakai, menambah poin yang ditukar, dan mencatat pengingat (App\Support\CrmGuard).
            'crm' => ['scope' => 'business', 'read' => ['prices.edit', 'payments.receive'], 'write' => ['prices.edit', 'payments.receive']],
            'couriers' => ['scope' => 'business', 'read' => ['courier.assign', 'courier.tasks'], 'write' => ['courier.assign']],
            'stock_items' => ['scope' => 'business', 'read' => ['stock.manage', 'stock.use'], 'write' => ['stock.manage']],
            'stock_ledger' => ['scope' => 'business', 'read' => ['stock.manage', 'stock.use'], 'write' => ['stock.manage', 'stock.use']],
            'stock_suppliers' => ['scope' => 'business', 'read' => ['stock.manage'], 'write' => ['stock.manage']],
            'stock_purchases' => ['scope' => 'business', 'read' => ['stock.manage'], 'write' => ['stock.manage']],
            'stock_recipes' => ['scope' => 'business', 'read' => ['stock.manage', 'stock.use'], 'write' => ['stock.manage']],
        ],
    ],

    /*
     | Aturan pesanan yang ditegakkan server saat sinkronisasi (App\Support\OrderGuard).
     | Keputusan pengguna 8 Oktober 2026: pegawai memajukan satu tahap sampai Selesai Proses,
     | hanya kasir/admin outlet/owner yang menandai Siap Ambil, kurir hanya tugasnya sendiri
     | dan tidak bisa mengubah harga, diskon, atau isi pesanan yang sudah tersimpan.
     */
    'orders' => [
        'stages' => ['cuci', 'kering', 'setrika', 'packing'],
        // Nama tahap pada layanan (kolom "proc") => kunci status.
        'stage_names' => ['Cuci' => 'cuci', 'Kering' => 'kering', 'Setrika' => 'setrika', 'Packing' => 'packing'],
        'done_status' => 'selesaiproses',
        'statuses' => ['jemput', 'antrian', 'cuci', 'kering', 'setrika', 'packing', 'selesaiproses', 'siap', 'telat', 'diantar', 'diambil', 'batal'],
        // Aplikasi lama belum mengirim alasan saat mundur tahap; nyalakan setelah aplikasi mengirimnya.
        'require_reason_for_backward' => false,
    ],

    // Ambang peringatan otomatis untuk owner (App\Support\Monitoring).
    'alerts' => [
        'courier_cash_hours' => 24,   // tunai terlalu lama dipegang kurir
        'device_stale_hours' => 24,   // HP kasir belum sinkron
        'uncollected_days' => 7,      // siap ambil tidak diambil
    ],
];
