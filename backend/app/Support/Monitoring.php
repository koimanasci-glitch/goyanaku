<?php
namespace App\Support;

use App\Models\{Business, CashierDevice, User};
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;

/**
 * Monitoring owner antar cabang (keputusan pengguna 8 Oktober 2026: "monitoring dibuat lengkap").
 * Semua angka dihitung dari catatan server (order_index, order_events, courier_ledger, kas tersinkron),
 * jadi tidak ada pencatatan tambahan oleh pegawai. Upah tidak dihitung: hanya siapa mengerjakan apa.
 */
final class Monitoring {
    public const TZ = 'Asia/Jakarta';
    private const CLOSED = ['diambil', 'batal'];

    public function __construct(private Business $business) {}

    /** @param ?int $outletId null = semua cabang */
    public function report(?int $outletId, CarbonImmutable $from, CarbonImmutable $to): array {
        $outlets = $this->business->outlets()->orderBy('id')->get()->when($outletId, fn ($c) => $c->where('id', $outletId))->values();
        $ids = $outlets->pluck('id')->all();
        $users = $this->business->users()->get(['id', 'name', 'role', 'outlet_id', 'courier_key', 'deactivated_at'])->keyBy('id');
        $name = fn ($id) => $users[$id]->name ?? 'Tidak dikenal';

        $index = DB::table('order_index')->where('business_id', $this->business->id)->whereIn('outlet_id', $ids)->where('deleted', false);
        $events = fn () => DB::table('order_events')->where('business_id', $this->business->id)->whereIn('outlet_id', $ids)->whereBetween('created_at', [$from->utc(), $to->utc()]);
        $now = now();

        // ---------- ringkasan dan cucian per cabang ----------
        $perOutlet = [];
        foreach ($outlets as $o) {
            $perOutlet[$o->id] = ['id' => $o->id, 'name' => $o->name, 'code' => $o->code, 'active' => $o->isActive(),
                'orders' => 0, 'revenue' => 0, 'cash_in' => 0, 'unpaid' => 0, 'debt' => 0,
                'stages' => [], 'in_process' => 0, 'ready_uncollected' => 0, 'late' => 0, 'pending_weigh' => 0];
        }
        foreach ((clone $index)->get(['outlet_id', 'status', 'total', 'paid', 'ordered_at', 'due_at', 'weigh_status']) as $r) {
            $o = &$perOutlet[$r->outlet_id];
            if ($r->status !== 'batal') {
                $ordered = $r->ordered_at ? CarbonImmutable::parse($r->ordered_at, 'UTC') : null;
                if ($ordered && $ordered->betweenIncluded($from, $to)) { $o['orders']++; $o['revenue'] += (int) $r->total; }
                if ((int) $r->paid < (int) $r->total) { $o['unpaid']++; $o['debt'] += (int) $r->total - (int) $r->paid; }
            }
            if (!in_array($r->status, self::CLOSED, true)) {
                $o['stages'][$r->status] = ($o['stages'][$r->status] ?? 0) + 1;
                if (in_array($r->status, ['siap', 'telat'], true)) $o['ready_uncollected']++;
                elseif ($r->status !== 'diantar') {
                    $o['in_process']++;
                    if ($r->due_at && CarbonImmutable::parse($r->due_at, 'UTC')->lt($now)) $o['late']++;
                }
                if ($r->weigh_status === 'pending') $o['pending_weigh']++;
            }
            unset($o);
        }
        $paid = $events()->where('kind', 'bayar')->get(['outlet_id', 'user_id', 'role', 'details']);
        $byMethod = [];
        foreach ($paid as $p) {
            $d = json_decode((string) $p->details, true) ?: [];
            $perOutlet[$p->outlet_id]['cash_in'] += (int) ($d['amount'] ?? 0);
            $m = (string) ($d['method'] ?? 'Tunai');
            $byMethod[$m] = ($byMethod[$m] ?? 0) + (int) ($d['amount'] ?? 0);
        }
        $sum = fn (string $k) => array_sum(array_column($perOutlet, $k));

        // ---------- kinerja per orang ----------
        $cashiers = []; $production = []; $couriers = [];
        $person = fn (array &$list, $id, array $zero) => $list[$id] ??= ['id' => $id, 'name' => $name($id), 'outlet_id' => $users[$id]->outlet_id ?? null] + $zero;
        foreach ($events()->whereNotNull('user_id')->get(['kind', 'role', 'user_id', 'from_status', 'to_status', 'item_index', 'details']) as $e) {
            $d = json_decode((string) $e->details, true) ?: [];
            if (!empty($d['auto'])) continue; // status otomatis aplikasi bukan pekerjaan orang
            if ($e->role === 'produksi') {
                $person($production, $e->user_id, ['stages' => [], 'total' => 0]);
                if ($e->kind === 'maju') {
                    $production[$e->user_id]['stages'][$e->to_status] = ($production[$e->user_id]['stages'][$e->to_status] ?? 0) + 1;
                    $production[$e->user_id]['total']++;
                }
            } elseif ($e->role === 'kurir') {
                $person($couriers, $e->user_id, ['pickups' => 0, 'deliveries' => 0, 'created' => 0, 'cash_collected' => 0, 'weigh_corrected' => 0]);
                if ($e->kind === 'buat') $couriers[$e->user_id]['created']++;
                if ($e->kind === 'maju' && $e->from_status === 'jemput') $couriers[$e->user_id]['pickups']++;
                if ($e->kind === 'maju' && $e->to_status === 'diambil') $couriers[$e->user_id]['deliveries']++;
                if ($e->kind === 'bayar' && mb_strtolower((string) ($d['method'] ?? '')) === 'tunai') $couriers[$e->user_id]['cash_collected'] += (int) ($d['amount'] ?? 0);
            } else {
                $person($cashiers, $e->user_id, ['role' => $e->role, 'created' => 0, 'received' => 0, 'cancelled' => 0, 'skipped' => 0, 'moved_back' => 0, 'marked_ready' => 0]);
                $c = &$cashiers[$e->user_id];
                if ($e->kind === 'buat') $c['created']++;
                if ($e->kind === 'bayar') $c['received'] += (int) ($d['amount'] ?? 0);
                if ($e->kind === 'batal') $c['cancelled']++;
                if ($e->kind === 'lompat') $c['skipped']++;
                if ($e->kind === 'mundur') $c['moved_back']++;
                if ($e->to_status === 'siap' && $e->item_index === null) $c['marked_ready']++;
                unset($c);
            }
            if ($e->kind === 'timbang' && !empty($d['changed']) && !empty($d['courier_id'])) {
                $person($couriers, $d['courier_id'], ['pickups' => 0, 'deliveries' => 0, 'created' => 0, 'cash_collected' => 0, 'weigh_corrected' => 0]);
                $couriers[$d['courier_id']]['weigh_corrected']++;
            }
        }

        // ---------- uang ----------
        $held = $this->courierCash($ids);
        $deposits = DB::table('courier_ledger')->where('business_id', $this->business->id)->whereIn('outlet_id', $ids)->where('type', 'deposit')
            ->whereBetween('created_at', [$from->utc(), $to->utc()])->orderByDesc('id')->get()
            ->map(fn ($d) => ['courier_id' => $d->courier_id, 'courier' => $name($d->courier_id), 'outlet_id' => $d->outlet_id, 'expected' => (int) $d->expected,
                'received' => (int) $d->amount, 'difference' => (int) $d->amount - (int) $d->expected, 'confirmed_by' => $name($d->confirmed_by),
                'note' => $d->note, 'at' => CarbonImmutable::parse($d->created_at, 'UTC')->toIso8601String()])->all();

        // ---------- penjemputan yang sedang berjalan (keputusan pengguna 9 Oktober 2026) ----------
        // Penjemputan dari aplikasi = pesanan berstatus 'jemput' (berat ditimbang kurir di lokasi).
        $pickups = $this->pickups(clone $index, $users);

        return [
            'range' => ['from' => $from->toIso8601String(), 'to' => $to->toIso8601String(), 'timezone' => self::TZ],
            'scope' => $outletId ? 'outlet' : 'all',
            'totals' => ['orders' => $sum('orders'), 'revenue' => $sum('revenue'), 'cash_in' => $sum('cash_in'), 'unpaid' => $sum('unpaid'), 'debt' => $sum('debt'),
                'in_process' => $sum('in_process'), 'ready_uncollected' => $sum('ready_uncollected'), 'late' => $sum('late'), 'pending_weigh' => $sum('pending_weigh')],
            'outlets' => array_values($perOutlet),
            'money' => ['cash_in_by_method' => $byMethod, 'courier_cash' => $held, 'courier_cash_total' => array_sum(array_column($held, 'held')),
                'deposits' => $deposits, 'cash_closes' => $this->cashCloses($ids, $from, $to)],
            'cashiers' => array_values($cashiers), 'production' => array_values($production), 'couriers' => array_values($couriers),
            'devices' => $this->devices($ids),
            'pickups' => $pickups,
            'alerts' => $this->alerts($outletId),
        ];
    }

    private const PICKUP_SLOTS = ['asap' => 'Secepatnya', 'pagi' => 'Pagi 08.00–11.00', 'siang' => 'Siang 11.00–15.00', 'sore' => 'Sore 15.00–18.00'];

    /** Penjemputan berjalan: pelanggan, jadwal, siapa yang menjemput, dan sejak kapan dibuat. */
    private function pickups($index, $users): array {
        $rows = $index->where('status', 'jemput')->orderBy('ordered_at')->limit(100)->get(['outlet_id', 'record_key', 'customer', 'courier_key', 'ordered_at']);
        if ($rows->isEmpty()) return [];
        $data = DB::table('sync_records')->where('business_id', $this->business->id)->where('collection', 'orders')
            ->whereIn('record_key', $rows->pluck('record_key')->all())->pluck('data', 'record_key');
        $byKey = $users->filter(fn ($u) => (string) $u->courier_key !== '')->keyBy('courier_key');
        $couriers = $this->collectionNames('couriers');
        return $rows->map(function ($r) use ($data, $byKey, $couriers) {
            $order = json_decode((string) ($data[$r->record_key] ?? ''), true);
            if (is_string($order)) $order = json_decode($order, true);
            $set = is_array($order) ? (array) ($order['card']['dataset'] ?? []) : [];
            $who = $r->courier_key ? ($byKey[$r->courier_key]->name ?? ($couriers[$r->courier_key] ?? 'Kurir')) : (string) ($set['jemputSelf'] ?? '');
            $slot = self::PICKUP_SLOTS[(string) ($set['jemputSlot'] ?? '')] ?? null;
            $date = (string) ($set['jemputDate'] ?? '');
            $when = $slot ? ($slot === 'Secepatnya' ? $slot : trim(($date !== '' ? CarbonImmutable::parse($date, self::TZ)->format('d M') : '').' · '.$slot, ' ·')) : null;
            return ['outlet_id' => (int) $r->outlet_id, 'order' => $r->record_key, 'customer' => $r->customer ?: '-', 'courier' => $who ?: null,
                'self' => !$r->courier_key && $who !== '', 'when' => $when,
                'address' => is_array($order) ? ((string) ($order['detail']['address'] ?? '')) ?: null : null,
                'since' => $r->ordered_at ? CarbonImmutable::parse($r->ordered_at, 'UTC')->toIso8601String() : null];
        })->values()->all();
    }

    /** Nama per kunci dari koleksi tersinkron (mis. data kurir lama tanpa akun). */
    private function collectionNames(string $collection): array {
        $out = [];
        foreach (DB::table('sync_records')->where('business_id', $this->business->id)->where('collection', $collection)->where('deleted', false)->get(['record_key', 'data']) as $row) {
            $d = json_decode((string) $row->data, true);
            if (is_string($d)) $d = json_decode($d, true);
            if (is_array($d) && isset($d['name'])) $out[(string) $row->record_key] = (string) $d['name'];
        }
        return $out;
    }

    /** Tunai yang masih dipegang tiap kurir: yang diterima sejak setoran terakhir. */
    public function courierCash(?array $outletIds, ?int $courierId = null): array {
        // Untuk satu kurir, semua outlet dihitung: uang yang ia pegang tidak hilang dari catatan saat ia dipindah outlet.
        $rows = DB::table('courier_ledger')->where('business_id', $this->business->id)->when($outletIds !== null && !$courierId, fn ($q) => $q->whereIn('outlet_id', $outletIds))
            ->when($courierId, fn ($q) => $q->where('courier_id', $courierId))->orderBy('id')->get();
        $out = [];
        foreach ($rows as $r) {
            $c = &$out[$r->courier_id];
            $c ??= ['courier_id' => (int) $r->courier_id, 'held' => 0, 'since' => null, 'notes' => 0];
            if ($r->type === 'collect') { $c['held'] += (int) $r->amount; $c['since'] ??= (string) $r->created_at; $c['notes']++; }
            else { $c['held'] = 0; $c['since'] = null; $c['notes'] = 0; } // setoran menyelesaikan seluruh saldo; selisihnya tercatat di setoran itu
            unset($c);
        }
        $users = User::whereIn('id', array_keys($out))->get(['id', 'name', 'outlet_id'])->keyBy('id');
        return array_values(array_map(fn ($c) => ['courier' => $users[$c['courier_id']]->name ?? 'Kurir', 'outlet_id' => $users[$c['courier_id']]->outlet_id ?? null,
            'since' => $c['since'] ? CarbonImmutable::parse($c['since'], 'UTC')->toIso8601String() : null] + $c, array_filter($out, fn ($c) => $c['held'] > 0)));
    }

    /** Tutup kas tiap kasir, dibaca dari kas yang disinkronkan HP kasir (dua bentuk riwayat didukung). */
    private function cashCloses(array $outletIds, CarbonImmutable $from, CarbonImmutable $to): array {
        $out = [];
        $rows = DB::table('sync_records')->where('business_id', $this->business->id)->where('collection', 'kas')->where('deleted', false)->whereIn('outlet_id', $outletIds)->get(['outlet_id', 'data']);
        foreach ($rows as $row) {
            $kas = json_decode((string) $row->data, true);
            foreach ((array) ($kas['hist'] ?? []) as $h) {
                if (!is_array($h)) continue;
                $raw = $h['d'] ?? ($h['at'] ?? null);
                try { $at = is_string($raw) ? CarbonImmutable::parse($raw) : null; } catch (\Throwable) { $at = null; }
                if (!$at || !$at->betweenIncluded($from, $to)) continue;
                $out[] = ['outlet_id' => (int) $row->outlet_id, 'cashier' => (string) ($h['kasir'] ?? ($kas['kasir'] ?? '')), 'at' => $at->utc()->toIso8601String(),
                    'deposited' => isset($h['setor']) ? (int) $h['setor'] : (isset($h['physical']) ? (int) $h['physical'] : null),
                    'difference' => (int) ($h['diff'] ?? 0), 'note' => (string) ($h['note'] ?? '')];
            }
        }
        usort($out, fn ($a, $b) => strcmp($b['at'], $a['at']));
        return $out;
    }

    private function devices(array $outletIds): array {
        return CashierDevice::whereIn('outlet_id', $outletIds)->whereNull('revoked_at')->whereNotNull('device_uuid')->orderBy('outlet_id')->orderBy('slot')->get()
            ->map(fn ($d) => ['outlet_id' => $d->outlet_id, 'label' => $d->label, 'slot' => $d->slot,
                'last_sync_at' => $d->last_seen_at ? CarbonImmutable::parse($d->last_seen_at, 'UTC')->toIso8601String() : null])->all();
    }

    /** Peringatan otomatis untuk owner. */
    public function alerts(?int $outletId = null): array {
        $outlets = $this->business->outlets()->get()->when($outletId, fn ($c) => $c->where('id', $outletId))->keyBy('id');
        $ids = $outlets->keys()->all(); $now = now(); $cfg = config('goyana.alerts'); $alerts = [];
        $add = function (string $type, string $text, ?int $outlet, array $extra = []) use (&$alerts, $outlets) {
            $alerts[] = ['type' => $type, 'text' => $text, 'outlet_id' => $outlet, 'outlet' => $outlet ? ($outlets[$outlet]->name ?? null) : null] + $extra;
        };
        $index = fn () => DB::table('order_index')->where('business_id', $this->business->id)->whereIn('outlet_id', $ids)->where('deleted', false);

        foreach ($index()->whereNotIn('status', ['siap', 'telat', 'diantar', 'diambil', 'batal'])->whereNotNull('due_at')->where('due_at', '<', $now)
            ->selectRaw('outlet_id, count(*) as n')->groupBy('outlet_id')->get() as $r) {
            $add('late', $r->n.' cucian melewati batas waktu selesai.', (int) $r->outlet_id, ['count' => (int) $r->n]);
        }
        foreach ($index()->whereIn('status', ['siap', 'telat'])->whereNotNull('ready_at')->where('ready_at', '<', $now->copy()->subDays((int) $cfg['uncollected_days']))
            ->selectRaw('outlet_id, count(*) as n')->groupBy('outlet_id')->get() as $r) {
            $add('uncollected', $r->n.' cucian siap ambil belum diambil lebih dari '.$cfg['uncollected_days'].' hari.', (int) $r->outlet_id, ['count' => (int) $r->n]);
        }
        foreach ($this->courierCash($ids) as $c) {
            if ($c['since'] && CarbonImmutable::parse($c['since'])->lt($now->copy()->subHours((int) $cfg['courier_cash_hours']))) {
                $add('courier_cash', $c['courier'].' memegang tunai Rp'.number_format($c['held'], 0, ',', '.').' lebih dari '.$cfg['courier_cash_hours'].' jam.', $c['outlet_id'], ['amount' => $c['held']]);
            }
        }
        $names = User::where('business_id', $this->business->id)->pluck('name', 'id');
        foreach (DB::table('courier_ledger')->where('business_id', $this->business->id)->whereIn('outlet_id', $ids)->where('type', 'deposit')
            ->whereColumn('amount', '!=', 'expected')->where('created_at', '>=', $now->copy()->subDays(7))->orderByDesc('id')->get() as $d) {
            $diff = (int) $d->amount - (int) $d->expected;
            $add('deposit_difference', 'Setoran '.($names[$d->courier_id] ?? 'kurir').' '.($diff < 0 ? 'kurang' : 'lebih').' Rp'.number_format(abs($diff), 0, ',', '.').'.', (int) $d->outlet_id, ['amount' => $diff]);
        }
        foreach (CashierDevice::whereIn('outlet_id', $ids)->whereNull('revoked_at')->whereNotNull('device_uuid')
            ->where('last_seen_at', '<', $now->copy()->subHours((int) $cfg['device_stale_hours']))->where('last_seen_at', '>=', $now->copy()->subDays(30))->get() as $d) {
            $add('device_stale', $d->label.' belum sinkron lebih dari '.$cfg['device_stale_hours'].' jam.', (int) $d->outlet_id);
        }
        if (!$outletId) {
            $pending = 0;
            foreach (DB::table('sync_records')->where('business_id', $this->business->id)->where('collection', 'couriers')->where('deleted', false)->pluck('data') as $raw) {
                $c = json_decode((string) $raw, true);
                if (is_array($c) && ($c['active'] ?? true) !== false && empty($c['deleted']) && count((array) ($c['outlets'] ?? [])) !== 1) $pending++;
            }
            if ($pending) $add('courier_without_outlet', $pending.' kurir belum punya outlet dan belum bisa menerima tugas. Pilihkan satu outlet.', null, ['count' => $pending]);
        }
        return $alerts;
    }

    /** Ringkasan milik sendiri untuk kasir, pegawai, dan kurir (hari ini, WIB). Tanpa omzet outlet dan data orang lain. */
    public function own(User $user): array {
        $from = CarbonImmutable::now(self::TZ)->startOfDay()->utc(); $to = CarbonImmutable::now('UTC');
        $events = DB::table('order_events')->where('business_id', $this->business->id)->where('user_id', $user->id)->whereBetween('created_at', [$from, $to])->get(['kind', 'from_status', 'to_status', 'details']);
        $out = ['date' => CarbonImmutable::now(self::TZ)->toDateString(), 'role' => $user->role];
        $received = []; $created = 0; $stages = [];
        foreach ($events as $e) {
            $d = json_decode((string) $e->details, true) ?: [];
            if ($e->kind === 'buat') $created++;
            if ($e->kind === 'bayar') { $m = (string) ($d['method'] ?? 'Tunai'); $received[$m] = ($received[$m] ?? 0) + (int) ($d['amount'] ?? 0); }
            if ($e->kind === 'maju' && empty($d['auto'])) $stages[$e->to_status] = ($stages[$e->to_status] ?? 0) + 1;
        }
        if ($user->orderMode() === 'courier') {
            $cash = $this->courierCash([$user->outlet_id], $user->id)[0] ?? null;
            $open = DB::table('order_index')->where('business_id', $this->business->id)->where('courier_key', $user->courier_key)->where('deleted', false)
                ->whereIn('status', ['jemput', 'siap', 'telat', 'diantar'])->selectRaw('status, count(*) as n')->groupBy('status')->pluck('n', 'status');
            return $out + ['tasks' => ['pickup' => (int) ($open['jemput'] ?? 0), 'ready_to_deliver' => (int) ($open['siap'] ?? 0) + (int) ($open['telat'] ?? 0), 'delivering' => (int) ($open['diantar'] ?? 0)],
                'done_today' => ['pickups' => $events->where('kind', 'maju')->where('from_status', 'jemput')->count(), 'deliveries' => $events->where('kind', 'maju')->where('to_status', 'diambil')->count()],
                'cash_held' => (int) ($cash['held'] ?? 0), 'cash_held_since' => $cash['since'] ?? null];
        }
        if ($user->orderMode() === 'production') return $out + ['stages_done' => $stages, 'total' => array_sum($stages)];
        return $out + ['orders_created' => $created, 'received' => $received, 'received_total' => array_sum($received)];
    }
}
