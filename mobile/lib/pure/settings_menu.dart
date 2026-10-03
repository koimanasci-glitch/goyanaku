// Menu Pengaturan persis dari HTML (#settings), diambil dari index.html.

const settingsMenuJson = r'''{
 "title": "PENGATURAN",
 "sync": {
  "dot": "rgb(154, 160, 166)",
  "t": "Sinkronisasi server",
  "line": "Belum terhubung ke server · data hanya di HP ini",
  "who": "",
  "url": {
   "v": "",
   "ph": "https://app.goyana.id"
  },
  "save": "Simpan & masuk",
  "now": ""
 },
 "groups": [
  {
   "i": 0,
   "svg": "<svg viewBox=\"0 0 48 48\" width=\"44\" height=\"44\" aria-hidden=\"true\"><path d=\"M7 40V28l10-5h14l10 5v12\" fill=\"#3e5967\"></path><path d=\"m17 23 7 17 7-17\" fill=\"#e3e8eb\"></path><path d=\"m22 28 2-3 2 3-2 9Z\" fill=\"#e85c4f\"></path><rect x=\"17\" y=\"7\" width=\"14\" height=\"17\" rx=\"7\" fill=\"#ffd17a\"></rect><path d=\"M16 14V9c0-9 18-9 16 2l-6-4-10 7\" fill=\"#38535f\"></path></svg>",
   "icon": "",
   "t": "Profil",
   "s": "Konfigurasi Profil",
   "accordion": true,
   "open": false,
   "items": [
    {
     "j": 0,
     "icon": "👤",
     "t": "Akun",
     "badge": "",
     "s": "Profil, password dan informasi usaha"
    }
   ]
  },
  {
   "i": 1,
   "svg": "<svg viewBox=\"0 0 48 48\" width=\"44\" height=\"44\" aria-hidden=\"true\"><path d=\"M7 18h34v24H7Z\" fill=\"#ffe1a0\"></path><path d=\"M29 25h9v17h-9\" fill=\"#50b9d7\"></path><path d=\"M11 26h13v10H11Z\" fill=\"#8bd7e1\"></path><path d=\"m7 6-3 12h40L41 6Z\" fill=\"#f5eeec\"></path><path d=\"m7 6-3 12h8L14 6m7 0v12h8V6m7 0 2 12h6L41 6\" fill=\"#ef6654\"></path><path d=\"M6 18v3c0 5 8 5 8 0 0 5 8 5 8 0 0 5 8 5 8 0 0 5 8 5 8 0 0 5 6 5 6 0v-3\" fill=\"#ee8d7c\"></path></svg>",
   "icon": "",
   "t": "Outlet",
   "s": "Konfigurasi Profil Outlet dan Jam Operasional",
   "accordion": true,
   "open": false,
   "items": [
    {
     "j": 0,
     "icon": "🏪",
     "t": "Outlet",
     "badge": "",
     "s": "Tambah, ubah dan kelola outlet laundry"
    },
    {
     "j": 1,
     "icon": "🏢",
     "t": "Manajemen Cabang",
     "badge": "",
     "s": "Monitoring cabang tanpa memindahkan transaksi"
    }
   ]
  },
  {
   "i": 2,
   "svg": "<svg viewBox=\"0 0 48 48\" width=\"44\" height=\"44\" aria-hidden=\"true\"><path d=\"M9 15h30l-4 27H13Z\" fill=\"#49b4c8\"></path><path d=\"M6 14h36v6H6Z\" fill=\"#6ac8d6\"></path><path d=\"M14 13c0-9 20-9 20 0\" fill=\"none\" stroke=\"#db925f\" stroke-width=\"4\"></path><path d=\"m12 15 5-7 7 2 4-5 8 9\" fill=\"#be85c4\"></path><path d=\"M17 23v15m7-15v15m7-15v15M13 28h23m-22 6h20\" stroke=\"#21889e\" stroke-width=\"2\"></path></svg>",
   "icon": "",
   "t": "Layanan",
   "s": "Konfigurasi Layanan",
   "accordion": true,
   "open": false,
   "items": [
    {
     "j": 0,
     "icon": "🧺",
     "t": "Layanan",
     "badge": "",
     "s": "Jenis layanan, satuan dan harga"
    },
    {
     "j": 1,
     "icon": "⏱",
     "t": "Durasi Layanan",
     "badge": "",
     "s": "Reguler, Express, Kilat dan estimasi"
    },
    {
     "j": 2,
     "icon": "✿",
     "t": "Parfum",
     "badge": "",
     "s": "Tambah, ubah dan hapus pilihan parfum"
    },
    {
     "j": 3,
     "icon": "🏷",
     "t": "Diskon",
     "badge": "",
     "s": "Atur promo dan potongan transaksi"
    },
    {
     "j": 4,
     "icon": "🚚",
     "t": "Antar-Jemput",
     "badge": "",
     "s": "Aktif · ongkir, area & kurir"
    }
   ]
  },
  {
   "i": 3,
   "svg": "<svg viewBox=\"0 0 48 48\" width=\"44\" height=\"44\" aria-hidden=\"true\"><path d=\"M8 42V31c0-9 32-9 32 0v11\" fill=\"#81bbdc\"></path><path d=\"M16 26h16v16H16Z\" fill=\"#e8f1f6\"></path><rect x=\"17\" y=\"8\" width=\"14\" height=\"18\" rx=\"7\" fill=\"#f5c9a1\"></rect><path d=\"M14 10c0-13 21-12 21 0v5H14Z\" fill=\"#e96170\"></path><path d=\"M17 12h13\" stroke=\"#f6cb76\" stroke-width=\"4\"></path><path d=\"M12 31v11m24-11v11\" stroke=\"#fff\" stroke-width=\"3\"></path></svg>",
   "icon": "",
   "t": "Pegawai",
   "s": "Kelola data dan role pegawai",
   "accordion": true,
   "open": false,
   "items": [
    {
     "j": 0,
     "icon": "👥",
     "t": "Pegawai",
     "badge": "",
     "s": "Data pegawai dan hak akses"
    },
    {
     "j": 1,
     "icon": "🪪",
     "t": "Kasir",
     "badge": "",
     "s": "ID kasir, shift dan batas hak akses"
    },
    {
     "j": 2,
     "icon": "🛡",
     "t": "Audit Aktivitas",
     "badge": "",
     "s": "Riwayat transaksi dan aktivitas kasir"
    },
    {
     "j": 3,
     "icon": "🛵",
     "t": "Management Kurir",
     "badge": "",
     "s": "Akun, akses outlet, tugas antar-jemput"
    }
   ]
  },
  {
   "i": 4,
   "svg": "<svg viewBox=\"0 0 48 48\" width=\"44\" height=\"44\" aria-hidden=\"true\"><circle cx=\"24\" cy=\"12\" r=\"7\" fill=\"#f4ceab\"></circle><path d=\"M17 12c-5-14 19-13 14 0l-5-6-9 6\" fill=\"#514352\"></path><path d=\"M15 40V26c0-10 18-10 18 0v14\" fill=\"#e274ac\"></path><path d=\"M17 27 8 31m23-4 9 4\" stroke=\"#f4ceab\" stroke-width=\"3\"></path><path d=\"M4 30h9v12H4Z\" fill=\"#ffcf70\"></path><path d=\"M36 30h9v12h-9Z\" fill=\"#59c1dc\"></path><path d=\"M21 40v5m7-5v5\" stroke=\"#454c61\" stroke-width=\"3\"></path></svg>",
   "icon": "",
   "t": "Pelanggan",
   "s": "Kelola data pelanggan",
   "accordion": true,
   "open": false,
   "items": [
    {
     "j": 0,
     "icon": "🙋",
     "t": "Pelanggan",
     "badge": "",
     "s": "Database dan riwayat pelanggan"
    },
    {
     "j": 1,
     "icon": "💎",
     "t": "CRM Pelanggan",
     "badge": "",
     "s": "Pengingat, poin member & voucher"
    },
    {
     "j": 2,
     "icon": "◉",
     "t": "Hubungkan WhatsApp",
     "badge": "",
     "s": "Tambah perangkat dan pilih cabang WhatsApp"
    },
    {
     "j": 3,
     "icon": "🤖",
     "t": "WhatsApp & Chatbot",
     "badge": "🔒 Chatbot",
     "s": "Jawaban AI untuk pelanggan"
    },
    {
     "j": 4,
     "icon": "⚡",
     "t": "Balas Cepat & Trigger",
     "badge": "🔒 Chatbot",
     "s": "Template berdasarkan kata pelanggan"
    },
    {
     "j": 5,
     "icon": "💬",
     "t": "Otomasi Pelanggan",
     "badge": "🔒 Chatbot",
     "s": "Pesan selesai dan reminder otomatis"
    }
   ]
  },
  {
   "i": 5,
   "svg": "",
   "icon": "◉",
   "t": "Hubungkan WhatsApp",
   "s": "Tambah perangkat dan pilih cabang WhatsApp",
   "accordion": false,
   "open": false,
   "items": []
  },
  {
   "i": 6,
   "svg": "<svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.6\" stroke-linecap=\"round\" stroke-linejoin=\"round\" aria-hidden=\"true\"><path d=\"M13 2 4 13h7l-1 9 10-12h-7z\"></path></svg>",
   "icon": "",
   "t": "Balasan Cepat & Trigger",
   "s": "Atur kata pemicu, teks dan gambar balasan",
   "accordion": false,
   "open": false,
   "items": []
  },
  {
   "i": 7,
   "svg": "<svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.6\" stroke-linecap=\"round\" stroke-linejoin=\"round\" aria-hidden=\"true\"><rect x=\"4\" y=\"7\" width=\"16\" height=\"13\" rx=\"4\"></rect><path d=\"M12 3v4M9 3h6M8 12h.01M16 12h.01M8 16h8\"></path></svg>",
   "icon": "",
   "t": "Chatbot AI",
   "s": "Atur asisten dan pengetahuan laundry",
   "accordion": false,
   "open": false,
   "items": []
  },
  {
   "i": 8,
   "svg": "<svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.6\" stroke-linecap=\"round\" stroke-linejoin=\"round\" aria-hidden=\"true\"><path d=\"m3 11 18-8-8 18-3-8-7-2zM10 13l11-10\"></path></svg>",
   "icon": "",
   "t": "WhatsApp Blast",
   "s": "Buat promo dan pilih penerima",
   "accordion": false,
   "open": false,
   "items": []
  },
  {
   "i": 9,
   "svg": "<svg viewBox=\"0 0 48 48\" width=\"44\" height=\"44\" aria-hidden=\"true\"><path d=\"m17 4 7 4 7-4-3 9h-8Z\" fill=\"#b98945\"></path><path d=\"M18 12c-1 8-12 9-13 23-1 11 39 11 38 0-1-14-12-15-13-23Z\" fill=\"#c99649\"></path><path d=\"M19 12h11\" stroke=\"#885e2d\" stroke-width=\"3\"></path><text x=\"24\" y=\"34\" text-anchor=\"middle\" font-size=\"23\" font-family=\"Arial\" font-weight=\"bold\" fill=\"#ffe9aa\">$</text></svg>",
   "icon": "",
   "t": "Keuangan",
   "s": "Kelola Keuangan",
   "accordion": true,
   "open": false,
   "items": [
    {
     "j": 0,
     "icon": "▦",
     "t": "Pembayaran",
     "badge": "",
     "s": "QRIS dan rekening transfer"
    },
    {
     "j": 1,
     "icon": "💰",
     "t": "Keuangan & Kas",
     "badge": "",
     "s": "Kas dan kategori pengeluaran"
    },
    {
     "j": 2,
     "icon": "✎",
     "t": "Ralat & Log Koreksi",
     "badge": "",
     "s": "Koreksi salah input · khusus Admin Utama"
    },
    {
     "j": 3,
     "icon": "📦",
     "t": "Stok & Bahan",
     "badge": "",
     "s": "Deterjen, parfum, plastik dan stok minimum"
    },
    {
     "j": 4,
     "icon": "🔔",
     "t": "Reminder Pekerjaan",
     "badge": "",
     "s": "Deadline dan keterlambatan internal"
    },
    {
     "j": 5,
     "icon": "📊",
     "t": "Laporan",
     "badge": "",
     "s": "38 laporan usaha & export"
    },
    {
     "j": 6,
     "icon": "⚙",
     "t": "Deposit Pelanggan",
     "badge": "",
     "s": "Tambah saldo dan riwayat penggunaan"
    },
    {
     "j": 7,
     "icon": "📦",
     "t": "Stock Opname & Supplier",
     "badge": "",
     "s": "Ledger stok, transfer, pembelian & hutang"
    }
   ]
  },
  {
   "i": 10,
   "svg": "<svg viewBox=\"0 0 48 48\" width=\"44\" height=\"44\" aria-hidden=\"true\"><path d=\"M13 5h22v17H13Z\" fill=\"#eee9f5\" stroke=\"#303343\" stroke-width=\"2\"></path><rect x=\"5\" y=\"17\" width=\"38\" height=\"21\" rx=\"4\" fill=\"#746a89\" stroke=\"#303343\" stroke-width=\"2\"></rect><path d=\"M13 29h22v15H13Z\" fill=\"#efeaf7\" stroke=\"#303343\" stroke-width=\"2\"></path><path d=\"M17 33h14m-14 4h14m-14 4h11\" stroke=\"#777188\" stroke-width=\"2\"></path><circle cx=\"36\" cy=\"23\" r=\"2\" fill=\"#d5d0e0\"></circle></svg>",
   "icon": "",
   "t": "Printer",
   "s": "Kelola Printer dan Nota",
   "accordion": true,
   "open": false,
   "items": [
    {
     "j": 0,
     "icon": "🖨",
     "t": "Printer & Nota",
     "badge": "",
     "s": "Printer thermal dan format nota"
    },
    {
     "j": 1,
     "icon": "▥",
     "t": "Barcode & Label",
     "badge": "",
     "s": "Struk, barcode dan label pakaian"
    }
   ]
  },
  {
   "i": 11,
   "svg": "",
   "icon": "🗄",
   "t": "Pusat Data",
   "s": "Import, ekspor, backup dan restore",
   "accordion": false,
   "open": false,
   "items": []
  },
  {
   "i": 12,
   "svg": "<svg viewBox=\"0 0 48 48\" width=\"44\" height=\"44\" aria-hidden=\"true\"><path d=\"M9 43V5h22v38m0-22h8v22\" fill=\"#93cdd3\" stroke=\"#365c62\" stroke-width=\"2\"></path><path d=\"M14 11h4m5 0h4m-13 7h4m5 0h4m-13 7h4m5 0h4m-13 7h4m5 0h4\" stroke=\"#f6ffff\" stroke-width=\"4\"></path><path d=\"M17 43V36h8v7M5 44h38\" stroke=\"#365c62\" stroke-width=\"2\"></path></svg>",
   "icon": "",
   "t": "Tentang Kami",
   "s": "Informasi Mengenai Developer",
   "accordion": true,
   "open": false,
   "items": [
    {
     "j": 0,
     "icon": "?",
     "t": "Bantuan",
     "badge": "",
     "s": "Panduan penggunaan aplikasi"
    },
    {
     "j": 1,
     "icon": "ⓘ",
     "t": "Tentang Kami",
     "badge": "",
     "s": "Informasi GOYANA dan pengembang"
    },
    {
     "j": 2,
     "icon": "⚙",
     "t": "Izin Aplikasi",
     "badge": "",
     "s": "Kamera, lokasi, kontak, printer, dan notifikasi"
    }
   ]
  }
 ],
 "acct": {
  "badge": "FREE",
  "t": "Masa Aktif Paket",
  "s": "Trial Basic sampai 3/12/2026",
  "go": "Perpanjang",
  "stats": [],
  "acts": [
   "",
   ""
  ],
  "link": ""
 },
 "logout": "Keluar Akun",
 "version": "GOYANA Laundry · versi 2.7",
 "tutorial": "Panduan awal Goyana"
}''';
