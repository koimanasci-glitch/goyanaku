<?php
namespace App\Support;

use App\Models\{Business, Outlet, User};
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

/**
 * Cabang usaha. Dipakai dashboard web dan API aplikasi.
 * Batas jumlah cabang mengikuti paket (tidak diubah): 1 pusat + cabang paket.
 * Kode cabang (2–4 huruf) menjadi awalan nomor nota, contoh BKS-261008-1-0133.
 */
final class Outlets {
    public static function rules(User $owner, ?Outlet $outlet = null): array {
        return [
            'name' => [$outlet ? 'sometimes' : 'required', 'string', 'max:120'],
            'code' => ['nullable', 'string', 'regex:/^[A-Za-z]{2,4}$/'],
            'address' => ['nullable', 'string', 'max:300'],
            'phone' => ['nullable', 'string', 'max:20'],
            // null = dikerjakan di outlet ini; terisi = cucian dikirim ke outlet tersebut.
            'process_outlet_id' => ['nullable', 'integer', Rule::exists('outlets', 'id')->where('business_id', $owner->business_id)->whereNull('deactivated_at')],
        ];
    }

    public static function create(User $owner, array $data): Outlet {
        return DB::transaction(function () use ($owner, $data) {
            $business = Business::whereKey($owner->business_id)->lockForUpdate()->firstOrFail();
            $access = $business->currentAccess();
            abort_if($access['read_only'], 403, 'Paket sudah berakhir.');
            if ($business->outlets()->whereNull('deactivated_at')->count() >= $access['outlet_limit']) {
                throw ValidationException::withMessages(['name' => 'Paket '.$access['package'].' maksimal 1 pusat + '.$access['branches'].' cabang. Upgrade paket untuk menambah cabang.']);
            }
            $outlet = new Outlet(['name' => $data['name']]);
            $outlet->business_id = $business->id;
            self::fill($business, $outlet, $data);
            $outlet->save();
            self::ensureCode($outlet);
            Team::audit($owner, 'outlet.created', ['outlet_id' => $outlet->id]);
            return $outlet;
        });
    }

    public static function update(User $owner, Outlet $outlet, array $data): Outlet {
        abort_unless($outlet->business_id === $owner->business_id, 404);
        abort_if($owner->business->currentAccess()['read_only'], 403, 'Paket sudah berakhir.');
        return DB::transaction(function () use ($owner, $outlet, $data) {
            if (array_key_exists('name', $data)) $outlet->name = $data['name'];
            self::fill($owner->business, $outlet, $data);
            $outlet->save();
            self::ensureCode($outlet);
            Team::audit($owner, 'outlet.updated', ['outlet_id' => $outlet->id]);
            return $outlet;
        });
    }

    /** Cabang nonaktif tidak menerima transaksi baru; riwayatnya tetap. Outlet pusat tidak bisa dinonaktifkan. */
    public static function deactivate(User $owner, Outlet $outlet): void {
        abort_unless($outlet->business_id === $owner->business_id, 404);
        if ($outlet->id === (int) $owner->business->outlets()->orderBy('id')->value('id')) {
            throw ValidationException::withMessages(['outlet' => 'Outlet pusat tidak bisa dinonaktifkan.']);
        }
        if (User::where('outlet_id', $outlet->id)->whereNull('deactivated_at')->exists()) {
            throw ValidationException::withMessages(['outlet' => 'Pindahkan atau nonaktifkan pegawai cabang ini terlebih dahulu.']);
        }
        if ($outlet->deactivated_at) return;
        $outlet->deactivated_at = now(); $outlet->save();
        Outlet::where('process_outlet_id', $outlet->id)->update(['process_outlet_id' => null]);
        Team::audit($owner, 'outlet.deactivated', ['outlet_id' => $outlet->id]);
    }

    public static function activate(User $owner, Outlet $outlet): void {
        abort_unless($outlet->business_id === $owner->business_id, 404);
        if (!$outlet->deactivated_at) return;
        DB::transaction(function () use ($owner, $outlet) {
            $business = Business::whereKey($owner->business_id)->lockForUpdate()->firstOrFail();
            $access = $business->currentAccess();
            abort_if($access['read_only'], 403, 'Paket sudah berakhir.');
            if ($business->outlets()->whereNull('deactivated_at')->count() >= $access['outlet_limit']) {
                throw ValidationException::withMessages(['outlet' => 'Batas cabang paket '.$access['package'].' sudah penuh.']);
            }
            $outlet->deactivated_at = null; $outlet->save();
            Team::audit($owner, 'outlet.activated', ['outlet_id' => $outlet->id]);
        });
    }

    private static function fill(Business $business, Outlet $outlet, array $data): void {
        if (array_key_exists('address', $data)) $outlet->address = $data['address'] ?: null;
        if (array_key_exists('phone', $data)) $outlet->phone = $data['phone'] ? User::normalizePhone($data['phone']) : null;
        if (!empty($data['code'])) {
            $code = strtoupper($data['code']);
            if ($business->outlets()->where('code', $code)->when($outlet->exists, fn ($q) => $q->where('id', '!=', $outlet->id))->exists()) {
                throw ValidationException::withMessages(['code' => 'Kode '.$code.' sudah dipakai cabang lain.']);
            }
            $outlet->code = $code;
        }
        if (array_key_exists('process_outlet_id', $data)) {
            $target = $data['process_outlet_id'] ? (int) $data['process_outlet_id'] : null;
            if ($target !== null) {
                if ($outlet->exists && $target === $outlet->id) $target = null; // dikerjakan sendiri
                elseif (Outlet::whereKey($target)->value('process_outlet_id') !== null) {
                    throw ValidationException::withMessages(['process_outlet_id' => 'Outlet tujuan sendiri mengirim cuciannya ke outlet lain. Pilih outlet yang mengerjakan sendiri.']);
                } elseif ($outlet->exists && Outlet::where('process_outlet_id', $outlet->id)->exists()) {
                    throw ValidationException::withMessages(['process_outlet_id' => 'Outlet ini menerima kiriman cucian dari cabang lain, jadi harus mengerjakan sendiri.']);
                }
            }
            $outlet->process_outlet_id = $target;
        }
    }

    /** Cabang lama belum punya kode: dibuat dari namanya, unik dalam satu usaha. Owner bisa menggantinya. */
    public static function ensureCode(Outlet $outlet): string {
        if ($outlet->code) return $outlet->code;
        $words = preg_split('/[^A-Za-z]+/', strtoupper($outlet->name), -1, PREG_SPLIT_NO_EMPTY) ?: [];
        $words = array_values(array_diff($words, ['LAUNDRY', 'LAUNDRI', 'CABANG', 'OUTLET', 'TOKO'])) ?: ['OUT'];
        $base = substr(str_pad(end($words), 3, 'X'), 0, 3);
        $taken = Outlet::where('business_id', $outlet->business_id)->whereNotNull('code')->pluck('code')->all();
        $code = $base;
        for ($i = 2; in_array($code, $taken, true) && $i < 100; $i++) $code = substr($base, 0, $i < 10 ? 3 : 2).$i;
        $outlet->code = $code; $outlet->save();
        return $code;
    }

    public static function present(Outlet $outlet): array {
        return ['id' => $outlet->id, 'key' => $outlet->syncKey(), 'name' => $outlet->name, 'code' => self::ensureCode($outlet),
            'address' => $outlet->address, 'phone' => $outlet->phone, 'active' => $outlet->isActive(),
            'process_outlet_id' => $outlet->process_outlet_id];
    }
}
