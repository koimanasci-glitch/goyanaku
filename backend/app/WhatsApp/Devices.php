<?php
namespace App\WhatsApp;
use App\Models\{Business, Outlet, User};
use App\WhatsApp\Contracts\ChatkuGateway;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

final class Devices {
    public function __construct(private ChatkuGateway $gateway) {}
    public function owner(User $user): Business {
        abort_unless($user->isActive() && $user->isOwner(), 403);
        abort_if(config('goyana.require_email_verification') && !$user->hasVerifiedEmail(), 403, 'Verifikasi email diperlukan.');
        return $user->business;
    }
    public function entitlement(Business $b): array {
        $a = $b->currentAccess(); $package = $a['package'];
        $enabled = !$a['read_only'] && in_array($package, config('whatsapp.connection_packages', []), true);
        $extra = DB::table('wa_slot_grants')->where('business_id', $b->id)->whereNull('revoked_at')->where('starts_at', '<=', now())->where('ends_at', '>', now())->sum('slots');
        return ['limit' => $enabled ? (int) config('whatsapp.base_slots', 1) + (int) $extra : 0,
            'used' => DB::table('wa_devices')->where('business_id', $b->id)->count(),
            'status_allowed' => $enabled && in_array($package, config('whatsapp.status_packages', []), true),
            'services_allowed' => $enabled && in_array($package, config('whatsapp.services_packages', []), true)];
    }
    public function find(User $user, string $id): object {
        $b = $this->owner($user);
        return DB::table('wa_devices')->where(['id' => $id, 'business_id' => $b->id])->first() ?? abort(404);
    }
    /** Serializes quota reservation and retry-safe create per business. */
    public function save(User $user, array $data, bool $create): object {
        $b = $this->owner($user);
        try { $phone = Phone::normalize($data['phone']); }
        catch (\InvalidArgumentException $e) { throw ValidationException::withMessages(['phone' => $e->getMessage()]); }
        return DB::transaction(function () use ($b, $user, $data, $phone, $create) {
            Business::whereKey($b->id)->lockForUpdate()->firstOrFail();
            $old = DB::table('wa_devices')->where('id', $data['id'])->lockForUpdate()->first();
            abort_if($old && $old->business_id !== $b->id, 404);
            if (!$create) abort_unless($old, 404);
            $outlet = Outlet::where(['id' => $data['outlet_id'], 'business_id' => $b->id])->firstOrFail();
            abort_if(($outlet->deactivated_at ?? null) !== null, 422, 'Outlet nonaktif.');
            $quota = $this->entitlement($b);
            abort_if($quota['limit'] === 0, 403, 'Paket belum mendukung WhatsApp.');
            if ($old && $create) {
                abort_unless($old->phone === $phone && $old->outlet_id === $outlet->id && $old->name === $data['name'], 409, 'ID draf sudah dipakai untuk perangkat lain.');
                return $old;
            }
            abort_if(!$old && $quota['used'] >= $quota['limit'], 409, 'Slot WhatsApp penuh. Tambahkan slot berbayar.');
            abort_if(DB::table('wa_devices')->where(['business_id' => $b->id, 'phone' => $phone])->where('id', '!=', $data['id'])->exists(), 422, 'Nomor sudah terdaftar.');
            // Remote binding changes require explicit removal/disconnect; never silently retarget a live session.
            abort_if($old?->remote_id && ($phone !== $old->phone || $outlet->id !== $old->outlet_id), 409, 'Hapus sambungan lama sebelum mengganti nomor atau outlet.');
            if ($old) {
                abort_unless((int) $data['version'] === $old->version, 409, 'Data perangkat telah berubah. Muat ulang.');
                DB::table('wa_devices')->where('id', $old->id)->update(['name' => $data['name'], 'phone' => $phone, 'outlet_id' => $outlet->id, 'version' => $old->version + 1, 'updated_at' => now()]);
            } else DB::table('wa_devices')->insert(['id' => $data['id'], 'business_id' => $b->id, 'outlet_id' => $outlet->id, 'name' => $data['name'], 'phone' => $phone, 'created_at' => now(), 'updated_at' => now()]);
            return $this->find($user, $data['id']);
        });
    }
    public function allowed(object $d, string $feature): bool {
        $b = Business::find($d->business_id);
        if (!$b || !Outlet::where(['id' => $d->outlet_id, 'business_id' => $b->id])->exists()) return false;
        $outlet = Outlet::find($d->outlet_id);
        if (($outlet->deactivated_at ?? null) !== null) return false;
        $q = $this->entitlement($b);
        // Stable admission after downgrade: oldest N reservations retain eligibility.
        $ids = DB::table('wa_devices')->where('business_id', $b->id)->orderBy('created_at')->orderBy('id')->limit($q['limit'])->pluck('id')->all();
        return in_array($d->id, $ids, true) && ($feature === 'connection' || ($q[$feature.'_allowed'] ?? false));
    }
    public function connect(User $user, string $id, string $method): array {
        abort_unless(in_array($method, ['qr', 'code'], true), 422);
        $remote = DB::transaction(function () use ($user, $id) {
            $b = $this->owner($user); Business::whereKey($b->id)->lockForUpdate()->firstOrFail();
            $d = $this->find($user, $id);
            abort_unless($this->allowed($d, 'connection'), 403, 'Slot/paket tidak aktif.');
            $remote = $d->remote_id ?: $this->gateway->provision('goyana-wa:'.$d->id, $d->phone, $d->name);
            abort_if($remote === '', 502, 'Chatku tidak mengembalikan perangkat.');
            DB::table('wa_devices')->where('id', $id)->update(['remote_id' => $remote, 'status' => 'pairing', 'updated_at' => now()]);
            return $remote;
        });
        // Persist remote binding even if requesting a QR later fails, so deletion can disconnect it.
        $p = $this->gateway->pairing($remote, $method);
        $expires = \Carbon\CarbonImmutable::parse($p['expires_at'] ?? '1970-01-01');
        abort_unless(($p['kind'] ?? '') === $method && is_string($p['value'] ?? null) && $p['value'] !== '' && strlen($p['value']) <= 4096 && $expires->isFuture(), 502, 'QR/kode Chatku tidak valid.');
        return ['kind' => $method, 'value' => $p['value'], 'expires_at' => $expires->toIso8601String()];
    }
    public function refresh(User $user, string $id): object {
        return DB::transaction(function () use ($user, $id) {
            Business::whereKey($this->owner($user)->id)->lockForUpdate()->firstOrFail();
            $d = $this->find($user, $id);
            if ($d->remote_id) {
                $s = $this->gateway->status($d->remote_id);
                abort_unless(in_array($s['status'] ?? '', ['connected', 'disconnected', 'pairing'], true), 502);
                if ($s['status'] === 'connected') abort_unless(Phone::normalize($s['phone'] ?? '') === $d->phone, 409, 'Nomor yang dipasangkan berbeda.');
                DB::table('wa_devices')->where('id', $id)->update(['status' => $s['status'], 'status_checked_at' => now(), 'updated_at' => now()]);
            }
            return $this->find($user, $id);
        });
    }
    public function remove(User $user, string $id): void {
        DB::transaction(function () use ($user, $id) {
            Business::whereKey($this->owner($user)->id)->lockForUpdate()->firstOrFail();
            $d = $this->find($user, $id);
            // Failure keeps reservation; never release a slot while remote session may remain active.
            // Hapus di CHATKU juga (berhenti ditagih), bukan hanya putus.
            if ($d->remote_id) $this->gateway instanceof Contracts\ChatkuExtras ? $this->gateway->remove($d->remote_id) : $this->gateway->disconnect($d->remote_id);
            DB::table('wa_outbox')->where('device_id', $id)->where('state', '!=', 'sent')->update(['state' => 'cancelled', 'body' => '', 'recipient' => '']);
            DB::table('wa_devices')->where('id', $id)->delete();
        });
    }
    public function automation(User $user, string $id, bool $status, bool $services): object {
        return DB::transaction(function () use ($user, $id, $status, $services) {
            Business::whereKey($this->owner($user)->id)->lockForUpdate()->firstOrFail();
            $d = $this->find($user, $id);
            abort_if($status && !$this->allowed($d, 'status'), 403, 'Balas status belum tersedia pada paket ini.');
            abort_if($services && !$this->allowed($d, 'services'), 403, 'Balas layanan belum tersedia pada paket ini.');
            DB::table('wa_devices')->where('id', $id)->update(['reply_status' => $status, 'reply_services' => $services, 'version' => $d->version + 1, 'updated_at' => now()]);
            return $this->find($user, $id);
        });
    }
}
