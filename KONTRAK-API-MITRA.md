# Kontrak API Mitra CHATKU (v1)

Untuk mitra white-label (pertama: **GOYANA**). CHATKU = mesin WhatsApp; data (pelanggan, pesanan, balasan cepat,
knowledge, media) tetap milik mitra. Dokumen ini dipasang di kedua repo (`chatku` & `goyanaku`) — kedua sisi wajib mengikutinya.

- **Base URL:** `https://chatku.id/api/partner/v1`
- **Autentikasi:** `Authorization: Bearer ckp_…` (kunci dibuat di admin CHATKU → Mitra (vendor); hanya disimpan di server mitra, tidak pernah di aplikasi HP)
- **Format:** JSON. Sukses: `{"data": {…}}`. Gagal: `{"error": {"code": "…", "message": "…"}}` (+ `fields` untuk validasi, `retry_after` bila perlu diulang)
- **Batas:** 600 request/menit per mitra. IP server mitra bisa dikunci dari admin.
- **Semua aksi aman diulang** (idempotent) — lihat kolom "Ulang".

| Kode HTTP | Arti |
|---|---|
| 401 `unauthenticated` | Kunci salah / tidak ada |
| 403 `vendor_suspended`, `ip_not_allowed` | Mitra dinonaktifkan / IP tidak diizinkan |
| 402 `saldo_habis` | Saldo AI sub-akun tidak cukup |
| 404 `*_not_found` | Bukan milik mitra ini / tidak ada |
| 409 `device_offline`, `idempotency_conflict`, `provision_failed` | Perangkat belum tersambung / key dipakai untuk isi lain |
| 422 `validation_error`, `topup_rejected`, `blast_rejected`, `media_error`, `invalid_number` | Data tidak valid |
| 429 `rate_limited` | Terlalu banyak request (`Retry-After`) |
| 503 `pairing_not_ready`, `engine_unavailable`, `ai_busy`, `ai_error`, `ai_paused` | Sementara; ulangi setelah `retry_after` detik |

---

## 1. Sub-akun (satu per laundry)

| Metode | Path | Isi | Ulang |
|---|---|---|---|
| PUT | `/tenants/{ref}` | `{"name": "Laundry Bersih"}` | ya — `ref` = ID usaha di sistem mitra (huruf, angka, `._:-`, maks. 80) |
| GET | `/tenants/{ref}` | — | — |

Jawaban: `{"ref", "name", "ai_balance", "devices"}`. Sub-akun tidak bisa login ke CHATKU dan tidak menerima email/WA dari CHATKU.

## 2. Perangkat WhatsApp

| Metode | Path | Isi | Ulang |
|---|---|---|---|
| POST | `/tenants/{ref}/devices` | `{"key": "goyana-wa:12", "phone": "0812…", "label": "Cabang Bekasi"}` | ya, per `key` (201 baru, 200 sudah ada) |
| POST | `/devices/{id}/pairing` | `{"method": "qr" \| "code"}` | ya — QR yang sedang tampil tidak diganti |
| GET | `/devices/{id}` | — | — status nyata dari engine |
| POST | `/devices/{id}/disconnect` | — | ya |
| DELETE | `/devices/{id}` | — | 204 |

- **Perangkat:** `{"id", "key", "label", "status", "phone", "expected_phone", "phone_match", "connected_at", "last_seen_at"}`
  - `status`: `pending` · `qr` · `connecting` · `connected` · `disconnected` · `logged_out`
  - `phone_match`: `true` / `false` (nomor yang di-scan ≠ nomor didaftarkan → mitra sebaiknya memutus) / `null` (belum tersambung)
- **Pairing:** `{"kind": "qr"|"code", "value": "<isi QR / kode 8 huruf>", "expires_at": ISO-8601, "status"}`.
  QR berganti ±20 detik (tanya lagi setelah `expires_at`), kode berlaku ±3 menit. Bila sudah tersambung: `status = connected`, `value = null`.
  `503 pairing_not_ready` → ulangi setelah 3 detik. Nilai QR/kode **tidak pernah dikarang**.
- Di HP pemilik, WhatsApp → Perangkat tertaut menampilkan nama mitra (mis. **GOYANA**).
- Biaya: Rp15.000 per perangkat per bulan kalender (masuk tagihan gabungan mitra).

## 3. Kirim pesan

`POST /devices/{id}/messages` — header **`Idempotency-Key`** wajib (8–120 karakter, mis. `goyana-reply:<id outbox>`).

```json
{ "to": "6281234567890", "text": "Halo Kak…", "reply_to": "<wa id pesan masuk, opsional>",
  "media": { "url": "https://goyana.id/media/7?sig=…", "key": "media-7-v3", "filename": "harga.pdf" } }
```

- `202` → `{"message_id": 991, "status": "queued", "replayed": false}`; key sama + isi sama → `200` dengan `message_id` yang **sama** (`replayed: true`), engine juga memakai kunci yang sama → **tidak pernah terkirim dua kali** walau diulang setelah timeout.
- Key sama + isi beda → `409 idempotency_conflict`. Perangkat belum tersambung → `409 device_offline` (simpan di antrean, ulangi nanti).
- **Media**: link sementara milik mitra (https, JPG/PNG/WEBP maks. 5 MB, PDF maks. 10 MB). CHATKU mengunduh sekali dan menyimpan salinan 24 jam per `key` — ganti `key` bila isi file berubah. WEBP diubah ke JPG (supaya tidak tampil sebagai stiker).
- Jeda "sedang mengetik", batas per jam, dan anti-blokir dikerjakan CHATKU.
- `GET /messages/{id}` → `{"message_id", "status": queued|sent|delivered|read|failed, "error", …}`.

## 4. Blast (promo)

`POST /devices/{id}/blasts` — mitra yang memilih penerima (**hanya yang setuju promo, bukan STOP**) dan mempersonalisasi teks.

```json
{ "ref": "promo-okt-12", "name": "Promo Oktober",
  "recipients": [ { "to": "6281…", "text": "Halo Kak Budi, …", "ref": "cust-55" } ],
  "media": { "url": "…", "key": "promo-okt-v1" },
  "schedule_at": "2026-10-12T09:00:00+07:00", "send_from": "08:00", "send_until": "20:00" }
```

- Maks. 5.000 penerima; nomor dobel/rusak dibuang. `ref` sama → blast yang sama (`replayed: true`).
- Dikirim bergilir oleh mesin campaign CHATKU (jeda acak 20–60 detik, istirahat per 25 pesan, pemanasan nomor baru, jam kirim).
- `GET /blasts/{ref}?page=1` → ringkasan + `recipients` (500 per halaman). `POST /blasts/{ref}/cancel`.

## 5. AI (tanpa simpan data)

`POST /tenants/{ref}/ai`

```json
{ "question": "harga cuci kiloan berapa kak?", "purpose": "reply" | "setup",
  "business_name": "Laundry Bersih", "instructions": "Jawab ramah, panggil Kak.",
  "prices": "Cuci kiloan: Rp7.000/kg\n…", "knowledge": "Antar jemput gratis 3 km…", "data": "Pesanan GY-1: sedang disetrika…",
  "history": [ {"from": "customer", "text": "…"}, {"from": "me", "text": "…"} ],
  "media": [ {"id": "m7", "name": "Daftar harga", "description": "brosur harga kiloan"} ] }
```

Jawaban: `{"answer", "media_id", "handover", "cost", "balance", "model", "tokens_in", "tokens_out", "unverified_prices"}`

- Biaya dipotong dari saldo AI sub-akun: **biaya asli × kurs dolar hari ini (+2%) + margin 25%**. `cost` = rupiah yang dipotong.
- `media_id` → AI memilih file dari daftar `media` (kirim filenya lewat §3). `handover: true` → teruskan ke admin manusia.
- `unverified_prices` → angka rupiah di jawaban yang **tidak ada** di `prices`/`knowledge`/`data`. Bila tidak kosong, mitra sebaiknya tidak mengirim jawaban itu (kirim "admin akan cek harga").
- Isi percakapan tidak disimpan CHATKU; yang dicatat hanya token & biaya.
- `402 saldo_habis` → tampilkan popup isi saldo.

`POST /tenants/{ref}/ai-topup` — `{"amount": 50000, "reference": "<id pembayaran mitra>"}` (minimal Rp50.000, idempotent per `reference`) → `{"ai_balance"}`. Masuk tagihan gabungan mitra.

## 6. Webhook ke mitra

Satu alamat (diisi admin CHATKU), `POST` JSON:

```json
{ "id": "evt_01j…", "event": "message.received", "created_at": "2026-10-10T09:00:00+07:00",
  "tenant": "<ref>", "device": { "id": 12, "key": "goyana-wa:12", "phone": "62…" }, "data": { … } }
```

Header: `X-Chatku-Event`, `X-Chatku-Event-Id`, `X-Chatku-Timestamp`, `X-Chatku-Signature`.
**Verifikasi:** `hex(HMAC-SHA256(rahasia_webhook, timestamp + "." + body_mentah))` sama dengan `X-Chatku-Signature`, dan timestamp tidak lebih tua dari 5 menit.
Balas 2xx secepatnya (proses di antrean mitra). Gagal → diulang 6× (10 dtk … 1 jam). **Anti-dobel pakai `id`.**

| event | data |
|---|---|
| `message.received` | `message_id` (id WA), `from`, `name`, `type`, `text`, `is_group`, `received_at` |
| `message.from_me` | `message_id`, `to`, `self`, `type`, `text`, `sent_at` — pemilik membalas langsung dari HP → **mitra yang membuat bot diam** & menangani kode `#stop/#bot` di chat diri sendiri (`self: true`) |
| `message.status` | `message_id` (id CHATKU dari §3), `wa_message_id`, `to`, `status`, `error` |
| `device.status` | `status`, `previous`, `phone`, `phone_match` |
| `blast.message` | `blast_ref`, `to`, `ref`, `status` (sent/failed/skipped/delivered/read), `error` |
| `blast.status` | ringkasan blast (§4) + `reason` |
| `tenant.ai_low` | `balance`, `threshold` (device = null) |
| `test` | dari tombol uji |

Pesan masuk dari perangkat mitra **tidak** dibalas otomatis oleh CHATKU (tanpa balasan cepat/AI/STOP CHATKU) — semua keputusan di mitra.

## 7. Ringkasan & uji

- `GET /overview` → perangkat (tersambung/putus/pairing), sub-akun, pesan hari ini, blast berjalan, AI hari ini, tagihan bulan berjalan, **daya tampung server** (RAM, sisa nomor WA & laundry).
- `POST /webhook/test` → kirim event `test` ke webhook mitra.

## 8. Pemetaan ke `ChatkuGateway` GOYANA

| GOYANA | API Mitra |
|---|---|
| `provision($key, $phone, $label)` | `PUT /tenants/{business}` lalu `POST /tenants/{business}/devices` → `id` jadi `remote_id` |
| `pairing($remoteId, $method)` | `POST /devices/{id}/pairing` |
| `status($remoteId)` | `GET /devices/{id}` (wajib cek `phone_match`) |
| `disconnect($remoteId)` | `POST /devices/{id}/disconnect` (hapus: `DELETE /devices/{id}`) |
| `send($remoteId, $phone, $text, $key)` | `POST /devices/{id}/messages` + `Idempotency-Key: $key` → `message_id` |
| `verifyInbound($request)` | verifikasi tanda tangan §6 → `{id, device: device.id, from, text, occurred_at: received_at, from_me, group}` |
