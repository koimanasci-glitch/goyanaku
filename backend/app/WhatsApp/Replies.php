<?php
namespace App\WhatsApp;
use Illuminate\Support\Facades\DB;

final class Replies {
    /** Nomor nota lama (GY-YYMMDD-NNNN) dan baru (KODE-YYMMDD-HP-NNNN, mis. BKS-261008-1-0133). */
    public const ORDER_CODE = '/\b[A-Z]{2,4}-\d{6}-(?:[A-Z0-9]{1,6}-)?\d+\b/i';
    private const LABELS = ['jemput'=>'Menunggu penjemputan','antrian'=>'Dalam antrean','proses'=>'Sedang diproses','cuci'=>'Sedang dicuci','kering'=>'Sedang dikeringkan','setrika'=>'Sedang disetrika','packing'=>'Sedang dikemas','selesaiproses'=>'Selesai proses, menunggu konfirmasi kasir','siap'=>'Siap diambil','telat'=>'Belum diambil','diantar'=>'Sedang diantar','diambil'=>'Sudah diambil','batal'=>'Dibatalkan'];
    public function render(string $purpose, array $values = []): string {
        $body = DB::table('wa_templates')->where(['key'=>$purpose, 'purpose'=>$purpose, 'active'=>true, 'ai_draft'=>false])->value('body');
        // Inactive customized template disables that purpose (not silently falling back).
        if (!$body && DB::table('wa_templates')->where('key', $purpose)->exists()) return '';
        return Template::render($body ?: Template::DEFAULTS[$purpose], $values);
    }
    /** Indexed lookup from Claude's order_index. Never search by name, suffix, or order code alone. */
    public function status(object $device, string $sender, string $message): string {
        $phone = Phone::normalize($sender);
        $q = DB::table('order_index')->where(['business_id'=>$device->business_id, 'outlet_id'=>$device->outlet_id, 'customer_key'=>'phone:'.$phone, 'deleted'=>false]);
        if (preg_match(self::ORDER_CODE, $message, $m)) $q->where('record_key', strtoupper($m[0]));
        else $q->whereNotIn('status', ['diambil','batal']);
        $orders = $q->orderByDesc('ordered_at')->limit(6)->get();
        if ($orders->isEmpty()) return $this->render('not_found');
        if ($orders->count() > 1) return $this->render('choose', ['daftar_pesanan'=>$orders->take(5)->map(fn($o)=>'• '.$o->record_key)->implode("\n")]);
        $o = $orders->first(); $due = 'belum tersedia';
        if ($o->due_at) { try { $due = \Carbon\CarbonImmutable::parse($o->due_at)->timezone('Asia/Jakarta')->format('d/m/Y H:i').' WIB (perkiraan)'; } catch (\Throwable) {} }
        return $this->render('status', ['kode_pesanan'=>$o->record_key, 'status'=>self::LABELS[$o->status] ?? 'Status belum dikenali; konfirmasi ke admin', 'estimasi'=>$due,
            'nama_outlet'=>DB::table('outlets')->where(['id'=>$device->outlet_id, 'business_id'=>$device->business_id])->value('name') ?? 'outlet']);
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
