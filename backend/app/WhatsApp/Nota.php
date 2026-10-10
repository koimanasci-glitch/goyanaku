<?php
namespace App\WhatsApp;

use App\Support\OrderData;
use Illuminate\Support\Facades\{DB, URL};

/**
 * Nota digital publik untuk pelanggan (link di WhatsApp). Link bertanda tangan & kedaluwarsa 30 hari;
 * hanya menampilkan isi satu nota (tanpa nomor HP lengkap, tanpa pesanan lain).
 */
final class Nota {
    public static function url(object $order): string {
        return URL::temporarySignedRoute('wa.nota', now()->addDays(30), ['b' => (int) $order->business_id, 'k' => $order->record_key]);
    }

    /** @return array|null data siap tampil */
    public static function view(int $businessId, string $key): ?array {
        $idx = DB::table('order_index')->where(['business_id' => $businessId, 'record_key' => $key, 'deleted' => false])->first();
        if (!$idx) return null;
        $raw = DB::table('sync_records')->where(['business_id' => $businessId, 'collection' => 'orders', 'record_key' => $key, 'deleted' => false])->value('data');
        $d = is_string($raw) ? json_decode($raw, true) : null;
        $items = is_array($d) ? OrderData::items($d) : [];
        $outlet = DB::table('outlets')->where(['id' => $idx->outlet_id, 'business_id' => $businessId])->first();
        $tz = \App\Models\Outlet::zoneOf((int) $idx->outlet_id);
        $fmt = fn ($t) => $t ? \Carbon\CarbonImmutable::parse($t)->timezone($tz)->format('d/m/Y H:i').' '.\App\Models\Outlet::labelOf($tz) : '—';
        return [
            'business' => (string) DB::table('businesses')->where('id', $businessId)->value('name'),
            'outlet' => $outlet?->name ?? '', 'address' => $outlet?->address ?? '', 'phone' => $outlet?->phone ?? '',
            'code' => $idx->record_key, 'customer' => trim(Replies::firstName($idx->customer)),
            'status' => Replies::LABELS[$idx->status] ?? $idx->status, 'ordered' => $fmt($idx->ordered_at), 'due' => $fmt($idx->due_at),
            'items' => array_map(fn ($i) => ['name' => (string) ($i['n'] ?? $i['name'] ?? 'Layanan'), 'qty' => (float) ($i['qty'] ?? 0), 'unit' => (string) ($i['unit'] ?? ''),
                'total' => (int) round((float) ($i['qty'] ?? 0) * (float) ($i['price'] ?? 0))], $items),
            'discount' => (int) $idx->discount, 'ongkir' => is_array($d) ? OrderData::ongkir($d) : 0,
            'total' => (int) $idx->total, 'paid' => (int) $idx->paid, 'left' => max(0, (int) $idx->total - (int) $idx->paid), 'delivery' => (bool) $idx->delivery,
        ];
    }
}
