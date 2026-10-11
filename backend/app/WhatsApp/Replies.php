<?php
namespace App\WhatsApp;
use Illuminate\Support\Facades\DB;

final class Replies {
    /** Nomor nota lama (GY-YYMMDD-NNNN) dan baru (KODE-YYMMDD-HP-NNNN, mis. BKS-261008-1-0133). */
    public const ORDER_CODE = '/\b[A-Z]{2,4}-\d{6}-(?:[A-Z0-9]{1,6}-)?\d+\b/i';
    public const LABELS = ['jemput'=>'Menunggu penjemputan','antrian'=>'Dalam antrean','proses'=>'Sedang diproses','cuci'=>'Sedang dicuci','kering'=>'Sedang dikeringkan','setrika'=>'Sedang disetrika','packing'=>'Sedang dikemas','selesaiproses'=>'Selesai proses, menunggu konfirmasi kasir','siap'=>'Siap diambil','telat'=>'Belum diambil','diantar'=>'Sedang diantar','diambil'=>'Sudah diambil','batal'=>'Dibatalkan'];
    public function render(string $purpose, array $values = []): string {
        $values += ['nama_outlet' => 'outlet', 'nama_pelanggan' => '', 'tagihan' => '', 'pengambilan' => ''];
        $body = DB::table('wa_templates')->where(['key'=>$purpose, 'purpose'=>$purpose, 'active'=>true, 'ai_draft'=>false])->value('body');
        // Inactive customized template disables that purpose (not silently falling back).
        if (!$body && DB::table('wa_templates')->where('key', $purpose)->exists()) return '';
        return Template::render($body ?: Template::DEFAULTS[$purpose], $values);
    }
    public static function rp(int|float $n): string { return 'Rp'.number_format((int) round($n), 0, ',', '.'); }

    public function outletName(object $d): string {
        return (string) (DB::table('outlets')->where(['id' => $d->outlet_id, 'business_id' => $d->business_id])->value('name') ?? 'outlet');
    }

    /** Tagihan satu pesanan (dari order_index): total, sudah dibayar, sisa. */
    public static function bill(object $o): string {
        $total = (int) $o->total; if ($total <= 0) return '';
        $left = max(0, $total - (int) $o->paid);
        return $left > 0 ? 'Tagihan: '.self::rp($total).((int) $o->paid > 0 ? ', sudah dibayar '.self::rp((int) $o->paid) : '').', sisa *'.self::rp($left)."*\n"
            : 'Pembayaran: *Lunas* ✅'."\n";
    }

    public static function pickup(object $o): string {
        if (in_array($o->status, ['diambil', 'batal'], true)) return '';
        if ($o->delivery) return $o->status === 'diantar' ? "Kurir sedang menuju alamat Kakak 🛵\n" : "Pesanan akan diantar kurir ke alamat Kakak 🛵\n";
        return $o->status === 'siap' || $o->status === 'telat' ? "Silakan diambil di outlet ya.\n" : '';
    }

    public function estimate(object $device, ?string $at): string {
        if (!$at) return 'belum tersedia';
        try {
            $tz = \App\Models\Outlet::zoneOf((int) $device->outlet_id);
            return \Carbon\CarbonImmutable::parse($at)->timezone($tz)->format('d/m/Y H:i').' '.\App\Models\Outlet::labelOf($tz);
        } catch (\Throwable) { return 'belum tersedia'; }
    }

    public static function firstName(?string $customer): string {
        $n = trim((string) preg_replace('/[^\pL\pN .\'-]/u', '', (string) $customer));
        $n = $n === '' ? '' : (preg_split('/\s+/u', $n)[0] ?? '');
        return $n === '' ? '' : ' '.mb_substr(mb_convert_case($n, MB_CASE_TITLE), 0, 20);
    }

    /** Nilai variabel template untuk satu pesanan. */
    public function values(object $device, object $o, array $extra = []): array {
        return $extra + ['kode_pesanan' => $o->record_key, 'status' => self::LABELS[$o->status] ?? 'Status belum dikenali; konfirmasi ke admin',
            'estimasi' => $this->estimate($device, $o->due_at), 'nama_outlet' => $this->outletName($device), 'nama_pelanggan' => self::firstName($o->customer),
            'tagihan' => self::bill($o), 'pengambilan' => self::pickup($o), 'link_nota' => Nota::url($o)];
    }

    /**
     * Indexed lookup from order_index (business + outlet + nomor pengirim). Never search by name or suffix alone.
     * Kode nota + 4 angka terakhir nomor pemesan boleh dipakai dari nomor lain (mis. keluarga), tetap tanpa membocorkan pesanan lain.
     */
    public function status(object $device, string $sender, string $message, string $intent = 'status'): string {
        $phone = Phone::normalize($sender);
        $base = fn () => DB::table('order_index')->where(['business_id'=>$device->business_id, 'outlet_id'=>$device->outlet_id, 'deleted'=>false]);
        $q = $base()->where('customer_key', 'phone:'.$phone);
        $code = preg_match(self::ORDER_CODE, $message, $m) ? strtoupper($m[0]) : null;
        if ($code) $q->where('record_key', $code);
        else $q->whereNotIn('status', ['diambil','batal']);
        $orders = $q->orderByDesc('ordered_at')->limit(6)->get();
        if ($orders->isEmpty() && $code && preg_match('/(?<!\d)(\d{4})(?!\d)/', str_replace($code, '', strtoupper($message)), $d4)) {
            // Anti tebak: maks. 5 percobaan per kode nota per hari; jawaban jalur ini tanpa nama, tagihan, dan link nota.
            $guard = 'wa-code4:'.$device->business_id.':'.$code;
            if (!\Illuminate\Support\Facades\RateLimiter::tooManyAttempts($guard, 5)) {
                \Illuminate\Support\Facades\RateLimiter::hit($guard, 86400);
                $o = $base()->where('record_key', $code)->first();
                if ($o && str_starts_with((string) $o->customer_key, 'phone:') && str_ends_with((string) $o->customer_key, $d4[1])) {
                    return $this->render('status', ['nama_pelanggan' => '', 'tagihan' => '', 'link_nota' => ''] + $this->values($device, $o));
                }
            }
        }
        $outlet = $this->outletName($device);
        if ($orders->isEmpty()) return $this->render('not_found', ['nama_outlet' => $outlet]);
        if ($orders->count() > 1) {
            if ($intent === 'bill') return $this->render('bills', ['nama_outlet' => $outlet, 'daftar_pesanan' => $orders->take(5)->map(fn ($o) => '• '.$o->record_key.': '.(self::LABELS[$o->status] ?? $o->status).($this->left($o) > 0 ? ', sisa '.self::rp($this->left($o)) : ((int) $o->total > 0 ? ', lunas' : '')))->implode("\n")
                .(($sum = $orders->take(5)->sum(fn ($o) => $this->left($o))) > 0 ? "\nTotal belum dibayar: *".self::rp($sum).'*' : '')]);
            return $this->render('choose', ['daftar_pesanan'=>$orders->take(5)->map(fn($o)=>'• '.$o->record_key.' ('.(self::LABELS[$o->status] ?? $o->status).')')->implode("\n")]);
        }
        return $this->render('status', $this->values($device, $orders->first()));
    }

    private function left(object $o): int { return max(0, (int) $o->total - (int) $o->paid); }

    /** Pelanggan minta nota: link nota pesanan aktif terbaru milik nomor itu (atau kode yang disebut). */
    public function receipt(object $device, string $sender, string $message): string {
        $phone = Phone::normalize($sender);
        $q = DB::table('order_index')->where(['business_id'=>$device->business_id, 'outlet_id'=>$device->outlet_id, 'customer_key'=>'phone:'.$phone, 'deleted'=>false]);
        if (preg_match(self::ORDER_CODE, $message, $m)) $q->where('record_key', strtoupper($m[0]));
        $o = $q->orderByDesc('ordered_at')->first();
        return $o ? $this->render('receipt', $this->values($device, $o)) : $this->render('not_found', ['nama_outlet' => $this->outletName($device)]);
    }

    /** Jam buka / alamat / kontak outlet dari profil outlet yang tersinkron + data outlet di server. */
    public function hours(object $device): string {
        $outlet = DB::table('outlets')->where(['id' => $device->outlet_id, 'business_id' => $device->business_id])->first();
        $profiles = DB::table('sync_records')->where(['business_id' => $device->business_id, 'collection' => 'outlet_profiles', 'deleted' => false])->limit(50)->get();
        $p = null;
        foreach ($profiles as $r) {
            $d = json_decode((string) $r->data, true); if (!is_array($d)) continue;
            if ((int) $r->outlet_id === (int) $device->outlet_id || ($d['outletId'] ?? null) == $device->outlet_id || mb_strtolower((string) ($d['name'] ?? '')) === mb_strtolower((string) $outlet?->name)) { $p = $d; break; }
            $p ??= $profiles->count() === 1 ? $d : null;
        }
        $hours = $p['hours'] ?? null;
        $lines = array_filter([
            '*'.($outlet->name ?? 'Outlet').'*',
            ($a = $p['address'] ?? $outlet?->address) ? '📍 '.$a : null,
            $hours ? '🕘 '.(is_array($hours) ? implode(', ', $hours) : $hours) : null,
            !empty($p['maps']) ? '🗺 '.$p['maps'] : null,
            ($ph = $p['phone'] ?? $outlet?->phone) ? '☎ '.$ph : null,
        ]);
        return count($lines) > 1 ? implode("\n", $lines) : '';
    }

    public function pickupInfo(object $device): string {
        return 'Bisa Kak, kami melayani antar-jemput 🛵 Kirim alamat lengkap + share lokasi ya, admin '.$this->outletName($device).' akan konfirmasi ongkir dan jadwalnya.';
    }

    private function mentionsService(string $message, string $name): bool {
        $message=mb_strtolower($message); $name=mb_strtolower($name);
        if(str_contains($message,$name)) return true;
        $terms=array_filter(preg_split('/\s+/u',$name),fn($t)=>mb_strlen($t)>=4 && !in_array($t,['cuci','laundry','jasa','layanan','reguler','express'],true));
        foreach($terms as $term) if(preg_match('/(?<!\pL)'.preg_quote($term,'/').'(?!\pL)/u',$message))return true;
        return false;
    }
    /** Current synchronized catalog, not a cached AI claim. Only explicit active positive prices. */
    public function services(object $d, string $message): string {
        $records = DB::table('sync_records')->where(['business_id'=>$d->business_id,'collection'=>'services','deleted'=>false])->where(function($q) use($d) {$q->whereNull('outlet_id')->orWhere('outlet_id',$d->outlet_id);})->limit(100)->get();
        $lines=[]; $specific = !preg_match('/daftar (harga|layanan)|pricelist/i', $message);
        foreach ($records as $r) {
            $s=json_decode($r->data,true); if(!is_array($s) || ($s['active']??true) === false) continue;
            $name=trim((string)($s['name']??''));
            // Specific inquiry must match full configured service name. Missing = confirm with admin.
            if($name==='' || ($specific && !$this->mentionsService($message, $name))) continue;
            foreach (($s['prices']??[]) as $type=>$price) {
                if (($s['enabled'][$type]??true) !== false && is_numeric($price) && $price>0) $lines[]=$name.' · '.$type.': Rp'.number_format((float)$price,0,',','.').'/'.($s['unit']??'');
            }
        }
        if (!$lines) return $this->render('unknown_service');
        return $this->render('services',['nama_outlet'=>DB::table('outlets')->where('id',$d->outlet_id)->value('name'),'daftar_layanan'=>implode("\n",array_slice($lines,0,12))]);
    }
}
