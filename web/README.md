# Halaman status pelanggan

`customer-status.html` adalah tampilan web publik untuk tautan QR pada nota:
`https://goyana.id/s/<nomor pesanan>`.

**Frontend siap; route publik, otorisasi tautan, data pesanan, dan hosting belum
tersambung.** Jangan menampilkan seluruh data sinkronisasi atau mencari pesanan
lintas usaha hanya berdasarkan nomor yang dapat ditebak. Server harus menentukan
pesanan yang boleh dilihat dan mengirim payload publik minimum.

Untuk meninjau desain, buka `customer-status.html?preview=1`. Data contoh hanya
ada pada mode tersebut dan ditandai **Pratinjau**. Tanpa data, halaman menampilkan
“Status belum tersedia”. Tidak mengambil status contoh dari nomor pada URL.

Kontrak payload yang dapat diberikan server sebelum script halaman berjalan:

```js
window.GOYANA_STATUS_ORDER = {
  id: 'nomor pesanan',
  outlet: { name: 'Nama outlet', phone: 'nomor kontak outlet' },
  status: 'setrika',
  customer_first_name: 'Nama depan',
  services: ['Cuci Setrika · 4 kg', 'Reguler'],
  estimated_at: 'timestamp ISO dengan zona waktu',
  updated_at: 'timestamp ISO dengan zona waktu',
  total: 28000,
  payment_status: 'Belum Lunas',
  remaining: 28000
};
```

`id` wajib berupa teks. Semua bidang lainnya boleh tidak ada; elemen terkait
disembunyikan. Status mengikuti aplikasi: `jemput`, `antrian`, `cuci`, `kering`,
`setrika`, `packing`, `siap`, `diambil`, `batal`. Status tidak dikenal tidak
dianggap selesai. Nilai pembayaran berasal dari server, bukan hitungan baru
di halaman ini. Waktu ditampilkan dalam WIB.

Data dapat diperbarui oleh adapter melalui `GoyanaCustomerStatus.render(payload)`.
Tidak ada endpoint polling yang dikarang. Data tampil sebagai teks, bukan HTML.
Font Poppins memakai aset repo melalui path relatif; saat dihosting, sediakan
font yang sama dan sesuaikan path sesuai letak halaman publik.

Tes browser `tests/customer-status.cjs` dipanggil oleh bridge CI: lebar 390/320,
status lengkap, data kosong, payload tidak valid, dan escaping teks.
