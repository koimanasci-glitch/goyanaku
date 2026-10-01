# GOYANA Product & Engineering Roadmap

Dokumen ini adalah sumber acuan utama untuk melanjutkan pengembangan GOYANA agar keputusan produk, alur bisnis, keamanan, keuangan, stok, kurir, sinkronisasi, Laravel, dan Flutter tidak hilang atau berubah tanpa alasan.

> Status:
> - `[x]` sudah ada / sudah menjadi keputusan final
> - `[~]` sudah ada sebagian / masih prototype
> - `[ ]` belum dikerjakan
>
> Prinsip revisi: **ubah hanya bagian yang diminta dan jangan merusak bagian yang sudah fix.**

---

## 1. Visi Produk

GOYANA adalah aplikasi operasional laundry yang akan dijual melalui Google Play Store dan ditujukan untuk usaha laundry kecil sampai multi-cabang.

Target akhir bukan sekadar aplikasi kasir, tetapi sistem operasional lengkap:

- transaksi laundry
- pelanggan dan CRM
- cabang / outlet
- kasir dan pegawai
- kurir antar-jemput
- stok dan stock opname
- keuangan dan kas
- laporan owner
- WhatsApp / otomasi
- billing paket
- dashboard web owner
- dashboard administrator GOYANA
- sinkronisasi multi-device
- mode offline

Arsitektur akhir:

```text
Flutter Android
      |
      v
Laravel REST API / Auth / Business Logic
      |
      +--> Database pusat
      +--> Dashboard Owner Web
      +--> Dashboard Administrator GOYANA
      +--> Payment / WhatsApp / Webhook / Billing
```

Prototype HTML sekarang adalah **blueprint final UI + business flow** sebelum dipindahkan ke Laravel + Flutter.

---

## 2. Keputusan Teknologi

### Saat ini

- [x] UI utama berupa HTML/CSS/JavaScript.
- [x] APK pengujian dibungkus menggunakan Capacitor.
- [x] Data prototype masih banyak disimpan lokal di perangkat.
- [x] GitHub Actions membangun APK otomatis.
- [x] APK terbaru dipublikasikan otomatis ke GitHub Release `android-latest`.

### Target produksi

- [ ] Android ditulis ulang menggunakan **Flutter**.
- [ ] Backend menggunakan **Laravel**.
- [ ] Database server menggunakan MySQL/PostgreSQL.
- [ ] VPS menjadi pusat API dan database.
- [ ] Flutter menggunakan database lokal **SQLite** untuk mode offline.
- [ ] Dashboard Owner berbasis Laravel/Web.
- [ ] Dashboard Administrator GOYANA berbasis Laravel/Web.

---

## 3. Offline-First & Sinkronisasi

Keputusan final: **GOYANA harus tetap dapat dipakai sementara saat internet atau server bermasalah.**

### Aturan dasar

- [ ] Semua transaksi Flutter disimpan lebih dulu ke SQLite lokal.
- [ ] Setelah tersimpan lokal, aplikasi mencoba mengirim ke Laravel.
- [ ] Jika gagal, data masuk **Outbox / Pending Sync**.
- [ ] Retry otomatis dilakukan ketika koneksi kembali.
- [ ] Server mengembalikan acknowledgment sebelum data dianggap `SYNCED`.
- [ ] Aplikasi menampilkan status sinkronisasi dengan jelas.

Contoh indikator:

```text
🟢 Online · Semua data tersinkron
🟠 Offline · 7 data menunggu sinkronisasi
🔴 Sinkronisasi bermasalah · ketuk untuk lihat detail
```

### Data yang harus tetap bisa bekerja offline

- [ ] membuat transaksi
- [ ] memilih pelanggan yang sudah tersimpan lokal
- [ ] layanan dan harga cache terakhir
- [ ] DP / pembayaran tunai
- [ ] status proses cucian
- [ ] scan barcode lokal
- [ ] cetak nota / label
- [ ] input stok dan stock opname
- [ ] audit lokal
- [ ] tugas kurir yang sudah tersinkron sebelumnya

### Fitur yang membutuhkan server / internet

- QRIS dinamis
- WhatsApp otomatis / chatbot
- Google Play Billing
- sinkronisasi cabang real-time
- login pertama di perangkat baru
- backup cloud
- data terbaru dari perangkat/cabang lain

### Keamanan data lokal

- [ ] **Clear cache tidak boleh menghapus database transaksi.**
- [ ] Database transaksi tidak disimpan sebagai cache.
- [ ] Clear data / uninstall tetap dapat menghapus data lokal Android.
- [ ] Karena itu transaksi yang belum sync harus terlihat jelas.
- [ ] Logout diblok/peringatkan jika ada data belum sync.
- [ ] Sediakan tombol `Sinkronkan Sekarang`.
- [ ] Sediakan `Backup Darurat` bila memungkinkan.

### ID & anti-duplikat

Setiap record penting harus punya UUID unik.

Contoh:

```text
id
uuid
version
created_at
updated_at
synced_at
sync_status
soft_deleted_at
```

Nomor cantik untuk pelanggan tetap terpisah, contoh:

```text
GY-CIK-000183
```

### Conflict handling

- [ ] setiap record memiliki version/revision
- [ ] deteksi perubahan bersamaan antar perangkat
- [ ] aturan konflik jelas per jenis data
- [ ] data keuangan tidak boleh ditimpa diam-diam
- [ ] audit conflict disimpan

---

## 4. Multi-Tenant & Multi-Outlet

GOYANA akan dijual ke banyak usaha laundry. Isolasi tenant adalah kebutuhan wajib.

### Konsep

```text
Tenant / Business
  ├── Outlet A
  ├── Outlet B
  ├── Outlet C
  └── Users / Employees / Couriers
```

- [ ] setiap data inti memiliki `tenant_id`
- [ ] data operasional memiliki `outlet_id` jika relevan
- [ ] Laravel menentukan tenant dari session/token
- [ ] API **tidak boleh percaya tenant_id dari aplikasi klien**
- [ ] Laundry A tidak boleh bisa membaca Laundry B dengan manipulasi request

Owner dapat memiliki banyak outlet. Pegawai dan kurir dapat diberi akses ke satu atau beberapa outlet.

---

## 5. Akun, Login, Device & Security

### Role utama

- Owner / Admin Utama
- Supervisor / Manager
- Kasir
- Pegawai Produksi
- Kurir

### Authentication

- [ ] email / username + password
- [ ] password di-hash di server
- [ ] access token + refresh token
- [ ] PIN cepat setelah login pertama
- [ ] session expiry
- [ ] reset password
- [ ] reset PIN
- [ ] revoke session
- [ ] logout semua perangkat

### Device Management

Owner harus bisa melihat contoh:

```text
Samsung A55
Kasir: Rina
Outlet: Cikarang
Terakhir aktif: 10:42
Status: Aktif
```

- [ ] daftar perangkat login
- [ ] nama perangkat
- [ ] user
- [ ] outlet
- [ ] last active
- [ ] revoke device
- [ ] notifikasi login perangkat baru
- [ ] device limit bila paket mengatur

### Data lokal sensitif

- [ ] token disimpan di secure storage Flutter
- [ ] jangan simpan password plaintext
- [ ] database lokal sensitif dienkripsi bila diperlukan
- [ ] screenshot/privacy protection pada halaman sensitif dipertimbangkan

---

## 6. Role & Permission

Permission harus granular, bukan hanya Owner/Pegawai.

Contoh:

### Kasir

- buat transaksi ✅
- menerima pembayaran ✅
- diskon sesuai batas ✅
- ubah harga manual ❌ / perlu izin
- refund ❌ / perlu approval
- hapus transaksi ❌
- melihat laba bersih ❌

### Kurir

- lihat tugas ✅
- lihat nama pelanggan ✅
- lihat alamat/map ✅
- telepon/WA pelanggan ✅
- update pickup/delivery ✅
- melihat omzet ❌
- edit transaksi laundry ❌

### Supervisor

- stock opname ✅
- koreksi transaksi ✅
- tutup kas ✅
- approval tertentu ✅

### Owner

- semua akses ✅

- [ ] permission matrix
- [ ] outlet assignment per user
- [ ] employee dapat akses beberapa outlet
- [ ] akun dapat dinonaktifkan tanpa menghapus histori

---

## 7. Audit Log & Anti-Fraud

Semua aktivitas sensitif harus meninggalkan jejak permanen.

Contoh:

```text
Rina mengubah transaksi GY-0182
Rp80.000 -> Rp65.000
01/10/2026 14:32
Outlet Cikarang
Alasan: salah input berat
Disetujui: Supervisor Andi
```

Wajib log:

- login/logout
- transaksi baru
- perubahan transaksi
- pembatalan
- diskon
- manual price override
- pembayaran
- DP
- refund
- perubahan saldo deposit pelanggan
- stock adjustment
- stock opname
- transfer stok
- perubahan permission
- perubahan outlet
- perubahan konfigurasi pembayaran
- ralat

### Anti-fraud

- [ ] diskon besar membutuhkan PIN/approval
- [ ] refund membutuhkan approval
- [ ] hapus/batal transaksi setelah pembayaran membutuhkan approval
- [ ] perubahan harga manual tercatat
- [ ] selisih kas wajib alasan
- [ ] saldo kas negatif memberi warning
- [ ] audit log tidak bisa diedit kasir
- [ ] log sensitif tidak hard-delete

---

## 8. Pesanan & Produksi

Alur umum:

```text
Pilih Pelanggan
-> Pilih Layanan / Parfum
-> Input Berat / Qty
-> Opsi Nota
-> Opsi Barcode
-> Pembayaran
-> Produksi
-> Selesai
```

### Status produksi

```text
Antrian
-> Cuci
-> Kering
-> Setrika
-> Packing
-> Siap
-> Selesai / Diambil
```

- [x] proses produksi bertahap sudah menjadi konsep utama
- [x] barcode/label pakaian
- [x] QR scan untuk pickup
- [x] status order
- [x] estimasi selesai
- [x] reminder keterlambatan

---

## 9. Antar-Jemput, Map & Management Kurir

Keputusan penting: **Map harus punya fungsi operasional nyata, bukan hanya tersimpan sebagai alamat tambahan.**

### Pelanggan

- [x] pelanggan dapat memiliki alamat
- [x] pelanggan dapat menyimpan link/titik Google Maps di prototype
- [x] lokasi perlu tampil saat Edit Pelanggan
- [ ] produksi nanti simpan lat/lng terstruktur + address + maps_url
- [ ] order dapat memakai lokasi pelanggan
- [ ] order dapat override dengan lokasi khusus untuk pesanan tertentu

### Pickup

Alur final:

```text
Order Antar Jemput
-> Penjemputan
-> Assign Kurir
-> Menuju Lokasi
-> Sudah Dijemput
-> Sampai Outlet
-> Antrian Laundry
```

Aturan penting:

- [x] pesanan Antar-Jemput **tidak boleh langsung masuk Antrian**
- [x] status awal harus `Penjemputan`
- [x] sesudah `Sudah Dijemput` baru masuk proses menuju outlet/antrian

### Delivery

```text
Siap
-> Siap Antar
-> Assign Kurir
-> Dibawa Kurir
-> Diterima Pelanggan
-> Selesai
```

### Management Kurir

- [x] konsep management kurir terpisah dari kasir/pegawai
- [ ] akun kurir sendiri
- [ ] outlet access
- [ ] status aktif/nonaktif
- [ ] assign tugas
- [ ] map/navigasi
- [ ] telepon pelanggan
- [ ] WhatsApp pelanggan
- [ ] catatan pickup/delivery
- [ ] ongkir
- [ ] foto bukti
- [ ] nama penerima
- [ ] timestamp pickup/delivery
- [ ] GPS kurir saat konfirmasi
- [ ] COD bila dipakai

---

## 10. Pelanggan, Deposit & CRM

- [x] database pelanggan
- [x] avatar pria/wanita
- [x] alamat
- [x] map pelanggan
- [x] saldo/deposit pelanggan
- [x] top-up saldo prototype
- [x] riwayat saldo prototype
- [~] CRM / poin / voucher

Aturan akuntansi penting:

**Top-up deposit pelanggan bukan pendapatan laundry saat top-up.**

Pendapatan diakui saat deposit digunakan untuk membayar order.

---

## 11. Pembayaran & Keuangan

### Metode pembayaran

- [x] Tunai
- [x] Transfer
- [x] QRIS
- [x] Bayar Nanti / Piutang
- [x] DP / Uang Muka
- [x] Saldo Deposit

### Aturan pembayaran

- DP hanya mencatat uang yang benar-benar diterima.
- Sisa tagihan = piutang.
- Deposit pelanggan dipisahkan dari pendapatan saat top-up.
- Pembayaran dapat memiliki banyak payment entry.

### Idempotency

Wajib di backend produksi:

- [ ] setiap request pembayaran punya idempotency key
- [ ] retry tidak membuat pembayaran dobel
- [ ] QRIS webhook juga idempotent
- [ ] DP/refund/deposit idempotent

### Refund

Refund harus dibedakan dari ralat.

```text
Ralat  = koreksi kesalahan administrasi
Refund = uang benar-benar dikembalikan
```

Refund menyimpan:

- order asal
- nominal
- metode
- alasan
- petugas
- approval
- timestamp
- reference payment

- [ ] halaman refund
- [ ] partial refund
- [ ] full refund
- [ ] approval
- [ ] audit

### Tutup Kas / Shift

- [x] konsep modal awal
- [x] pembayaran tunai
- [x] uang fisik
- [x] selisih kas
- [x] catatan wajib saat selisih
- [x] rekonsiliasi QRIS/transfer prototype
- [x] riwayat tutup kas

Target produksi:

- [ ] shift_id
- [ ] user_id
- [ ] outlet_id
- [ ] opening_cash
- [ ] expected_cash
- [ ] physical_cash
- [ ] difference
- [ ] closing approval

### Tutup Periode / Lock

- [ ] lock periode laporan
- [ ] transaksi periode tertutup tidak bisa diedit biasa
- [ ] koreksi hanya melalui jurnal/ralat resmi

---

## 12. Omzet, Kas, HPP & Laba

Angka berikut **tidak boleh disamakan**:

### Omzet

Total nilai transaksi laundry yang valid.

### Kas Masuk

Jumlah uang yang benar-benar diterima.

### Piutang

```text
Total Tagihan - Pembayaran Diterima
```

### HPP

Biaya bahan yang dipakai untuk menghasilkan layanan.

### Laba Operasional

```text
Pendapatan
- HPP bahan
- biaya operasional
= laba operasional
```

- [x] bug Top Pelanggan yang sebelumnya berpotensi memakai sisa utang sudah diidentifikasi/fix dalam patch prototype
- [~] HPP/resep bahan sudah mulai menjadi prototype
- [ ] final accounting rules di Laravel

### Top Pelanggan

Harus dipisah:

- Total Belanja
- Total Pembayaran
- Piutang

Jangan menjadikan pelanggan dengan utang terbesar sebagai pelanggan dengan belanja terbesar.

---

## 13. Stok, Ledger & Stock Opname

Prinsip final: **stok tidak boleh hanya berupa satu angka yang bebas diedit.**

Formula:

```text
Stok Sistem
= Stok Awal
+ Pembelian
+ Transfer Masuk
- Pemakaian
- Transfer Keluar
- Rusak/Hilang
+/- Adjustment Opname
```

### Stock Ledger

Setiap mutasi menyimpan:

```text
inventory_item_id
outlet_id
type
qty
unit_cost
reference_type
reference_id
user_id
created_at
note
```

Tipe contoh:

- OPENING
- PURCHASE
- USAGE
- TRANSFER_OUT
- TRANSFER_IN
- WASTE
- OPNAME_ADJUSTMENT
- MANUAL_ADJUSTMENT

### Stock Opname

Contoh:

```text
Stok sistem : 10 L
Stok fisik  : 8 L
Selisih     : -2 L
Adjustment  : -2 L
```

Yang disimpan:

- stok sistem sebelum opname
- stok fisik
- selisih
- alasan
- pegawai
- outlet
- waktu

- [~] konsep ledger/opname mulai dimasukkan ke prototype
- [ ] backend ledger immutable
- [ ] approval adjustment besar

### Stok Per Outlet

Stok harus per cabang, bukan global.

```text
Pusat       20 L
Cikarang     8 L
Tambun       7 L
Bekasi      10 L
```

### Transfer Stok

```text
Dibuat
-> Dikirim
-> Dalam Perjalanan
-> Diterima Cabang Tujuan
```

Cabang tujuan harus mengonfirmasi penerimaan.

---

## 14. Resep Bahan & Pemakaian Otomatis

Contoh resep:

```text
Cuci Kering 1 kg
- Deterjen 20 ml
- Softener 10 ml
- Parfum 5 ml
```

Jika diproses 100 kg:

```text
Deterjen 2 L
Softener 1 L
Parfum 0.5 L
```

Tujuan:

- estimasi HPP
- estimasi pemakaian
- deteksi kebocoran bahan
- bandingkan teoritis vs stock opname fisik

- [~] prototype HPP/resep sudah mulai dibuat
- [ ] resep per layanan final di Laravel
- [ ] consumption posting ke stock ledger

---

## 15. Supplier, Purchasing & Hutang Supplier

Alur target:

```text
Stok Minimum
-> Purchase Request
-> Purchase Order
-> Supplier
-> Barang Datang
-> Penerimaan Barang
-> Stok Bertambah
-> Invoice Supplier
-> Hutang / Lunas
```

- [~] supplier/pembelian mulai diprototype
- [ ] supplier master
- [ ] purchase order
- [ ] goods receipt
- [ ] invoice supplier
- [ ] hutang supplier
- [ ] pembayaran hutang
- [ ] link ke cashflow
- [ ] audit

---

## 16. Laporan

Laporan harus memiliki filter:

- outlet
- periode
- user/pegawai bila relevan
- metode pembayaran
- status order

### Laporan Keuangan

- omzet
- kas diterima
- pembayaran per metode
- piutang
- DP
- deposit pelanggan
- pengeluaran
- HPP
- laba operasional
- refund
- selisih kas

### Laporan Operasional

- transaksi
- kg cucian
- status produksi
- ketepatan waktu
- keterlambatan
- pickup/delivery
- kurir

### Laporan Stok

- posisi stok
- minimum stock
- mutasi stok
- pembelian
- pemakaian teoritis
- opname
- variance
- nilai persediaan

---

## 17. Backup & Disaster Recovery

Server utama tidak boleh menjadi satu-satunya salinan data.

- [ ] backup database otomatis
- [ ] backup harian
- [ ] backup disimpan terpisah dari VPS utama
- [ ] retention beberapa versi
- [ ] backup file/upload penting
- [ ] restore test berkala
- [ ] log backup
- [ ] alert bila backup gagal

Tujuan: kerusakan VPS tidak boleh berarti kehilangan bisnis ribuan tenant.

---

## 18. Dashboard Owner Web

Target domain dapat menggunakan subdomain seperti:

```text
app.goyana.id
```

Owner dapat:

- melihat semua outlet
- omzet dan laporan
- transaksi
- pelanggan
- pegawai
- kurir
- stok
- stock opname
- supplier
- hutang
- audit
- perangkat login
- paket langganan
- invoice
- billing
- konfigurasi usaha

---

## 19. Dashboard Administrator GOYANA

Dashboard milik operator GOYANA, bukan tenant laundry.

Harus mencakup:

- tenant aktif
- trial
- subscription
- paket
- outlet
- user
- perangkat
- payment subscription
- suspend tenant
- reset akun
- support/ticket
- announcement
- statistik platform

### Health Monitoring

- API error rate
- failed jobs
- queue backlog
- database health
- storage usage
- failed sync
- device sync delay
- payment webhook failure
- WhatsApp gateway health
- backup terakhir
- tenant bermasalah

---

## 20. Billing & Google Play

Android produksi akan dijual melalui Play Store.

- [ ] subscription Android mengikuti sistem billing yang sesuai kebijakan Google Play saat implementasi
- [ ] entitlement disimpan di backend GOYANA
- [ ] backend menjadi sumber status paket
- [ ] web dashboard dapat memiliki billing web sesuai kebijakan yang berlaku saat implementasi
- [ ] entitlement Android dan web sinkron melalui server

Catatan: kebijakan Play Store dapat berubah. Selalu cek kebijakan terbaru saat implementasi production billing.

---

## 21. Paket GOYANA

Keputusan yang pernah dibahas dan harus dikonfirmasi kembali saat pricing final:

- Free Trial: 2 bulan
- seluruh fitur PRO dapat dicoba selama trial
- PRO
- SUPER PRO
- WhatsApp Chatbot hanya mulai SUPER PRO
- Balas Cepat & Trigger hanya mulai SUPER PRO

Batas cabang tidak boleh diasumsikan kembali tanpa keputusan produk terbaru karena arah monetisasi dapat menggunakan add-on cabang/chatbot.

---

## 22. UI / UX Rules

Arah desain:

- simple
- clean
- elegan
- profesional
- putih / abu sangat soft
- coral / merah sebagai aksen utama
- motif batik ringan pada header
- icon bergaya iOS/Apple
- font konsisten
- tidak menampilkan status bar palsu HP
- logo hanya di Beranda
- halaman lain tanpa logo
- tanpa hamburger

### Beranda

Arah terbaru:

- [x] grid diperluas menjadi 6 menu utama
- Tambah Transaksi
- Cari/Pesanan
- Kurir
- Pelanggan
- Laporan
- Pengaturan / kebutuhan operasional utama

Bottom navigation tetap mempertahankan fungsi penting termasuk scanner QR di tengah.

---

## 23. Data Model Minimum Untuk Laravel

Model inti yang perlu tersedia:

```text
Tenant
Outlet
User
Role
Permission
UserOutlet
Device
Customer
CustomerAddress
Order
OrderItem
OrderStatusHistory
Payment
Refund
CustomerDepositLedger
CourierTask
InventoryItem
InventoryLedger
StockOpname
StockTransfer
Supplier
PurchaseOrder
GoodsReceipt
SupplierInvoice
Expense
CashShift
AuditLog
Subscription
Entitlement
SyncOutbox / SyncCursor
```

Semua record penting menggunakan UUID.

---

## 24. API Safety

- [ ] rate limiting
- [ ] auth middleware
- [ ] tenant middleware
- [ ] permission middleware
- [ ] idempotency middleware untuk operasi uang
- [ ] request validation
- [ ] API versioning
- [ ] audit request sensitif
- [ ] signed webhook verification
- [ ] replay protection webhook
- [ ] secrets hanya di environment/server
- [ ] jangan menaruh credential produksi di Flutter

---

## 25. Soft Delete & Retention

Data bisnis penting jangan langsung dihapus permanen.

Gunakan soft delete untuk:

- pelanggan
- pegawai
- layanan
- supplier
- item inventory
- konfigurasi tertentu

Data pembayaran, refund, stock ledger, tutup kas dan audit log sebaiknya tidak dihapus seperti data biasa.

---

## 26. Prioritas Implementasi

### P0 - Blueprint HTML sempurna

- [ ] selesaikan semua alur UI
- [ ] test semua tombol
- [ ] test transaksi penuh
- [ ] test antar-jemput
- [ ] test map
- [ ] test kurir
- [ ] test pembayaran
- [ ] test stok/opname
- [ ] test keuangan
- [ ] test role flow secara konsep

### P1 - Backend Laravel

- [ ] tenant/outlet/auth
- [ ] roles/permissions
- [ ] customer/order/payment
- [ ] audit
- [ ] inventory ledger
- [ ] courier task
- [ ] subscription entitlement
- [ ] REST API

### P2 - Flutter Android

- [ ] replicate UI final HTML
- [ ] SQLite
- [ ] secure storage
- [ ] outbox sync
- [ ] camera/QR
- [ ] printer
- [ ] background sync
- [ ] push notification

### P3 - Offline & Reliability

- [ ] idempotency
- [ ] conflict resolution
- [ ] retry strategy
- [ ] sync diagnostics
- [ ] disaster recovery

### P4 - Web Dashboard

- [ ] Owner dashboard
- [ ] Administrator GOYANA
- [ ] billing
- [ ] device management
- [ ] platform monitoring

### P5 - Advanced Automation

- [ ] WhatsApp chatbot
- [ ] quick replies
- [ ] CRM automation
- [ ] advanced analytics
- [ ] operational anomaly alerts

---

## 27. Release Checklist Sebelum Dijual Serius

GOYANA belum dianggap production-ready sebelum minimal:

- [ ] server multi-tenant aktif
- [ ] backup teruji
- [ ] authentication aman
- [ ] role permission teruji
- [ ] audit log aktif
- [ ] payment idempotent
- [ ] offline sync teruji
- [ ] conflict handling teruji
- [ ] stock ledger teruji
- [ ] tutup kas teruji
- [ ] refund teruji
- [ ] data tenant isolation test
- [ ] device revoke test
- [ ] API rate limit
- [ ] crash/error logging
- [ ] monitoring server
- [ ] privacy policy
- [ ] terms of service
- [ ] account deletion flow
- [ ] Play Store requirements terpenuhi

---

## 28. Prinsip Pengembangan

1. **Jangan rusak fitur yang sudah fix saat menambah fitur baru.**
2. UI prototype harus mencerminkan business logic final.
3. Semua fitur baru harus dicek dampaknya ke:
   - keuangan
   - stok
   - cabang
   - pegawai
   - kurir
   - audit
   - laporan
   - permission
   - offline sync
4. Jangan mencampur omzet, kas masuk, piutang, deposit dan laba.
5. Jangan mengubah stok tanpa ledger.
6. Jangan membuat pembayaran tanpa idempotency di production.
7. Jangan mengandalkan local storage sebagai database production.
8. Server adalah source of truth setelah data berhasil tersinkron.
9. Perangkat tetap dapat bekerja sementara ketika offline.
10. Semua keputusan arsitektur baru yang bersifat penting harus ditambahkan ke file roadmap ini.

---

## 29. Next Review

Saat pengembangan dilanjutkan, mulai dari dokumen ini dan perbarui status checklist.

Prioritas diskusi berikutnya:

1. menyempurnakan seluruh UI HTML
2. QA alur order + antar-jemput + kurir
3. QA keuangan, DP, deposit, refund, tutup kas
4. QA stok, ledger, opname, supplier
5. finalisasi permission matrix
6. desain schema Laravel
7. desain protokol offline sync Flutter

---

**Dokumen ini harus terus diperbarui bersama perkembangan GOYANA.**
