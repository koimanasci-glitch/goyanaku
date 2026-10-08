<?php
namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Business extends Model {
    protected $fillable = ['name', 'trial_ends_at'];
    protected function casts(): array { return ['trial_ends_at' => 'immutable_datetime', 'ai_balance' => 'integer', 'allow_debt' => 'boolean']; }
    public function outlets() { return $this->hasMany(Outlet::class); }
    public function grants() { return $this->hasMany(PackageGrant::class); }
    public function subscriptions() { return $this->hasMany(Subscription::class); }
    public function users() { return $this->hasMany(User::class); }

    /** Query by current access state: paid | beta | trial | expired (null = all). Mirrors currentAccess(). */
    public static function withAccessStatus(?string $status) {
        $paying = fn ($q) => $q->whereHas('subscriptions', fn ($s) => $s->whereNull('cancelled_at')->where('starts_at', '<=', now())->where('ends_at', '>', now()));
        $beta = fn ($q) => $q->whereHas('grants', fn ($g) => $g->whereNull('revoked_at')->where('starts_at', '<=', now())->where('ends_at', '>', now()));
        $none = fn ($q) => $q->whereNot(fn ($x) => $paying($x))->whereNot(fn ($x) => $beta($x));
        $q = static::query();
        return match ($status) {
            'paid' => $paying($q),
            'beta' => $beta($q)->whereNot(fn ($x) => $paying($x)),
            'trial' => $none($q)->where('trial_ends_at', '>', now()),
            'expired' => $none($q)->where('trial_ends_at', '<=', now()),
            default => $q,
        };
    }

    /**
     * Server-side entitlement. Paid subscription or beta grant (highest package wins),
     * else the 2-month Basic trial, else read-only (data kept, writes locked).
     */
    public function currentAccess(): array {
        $now = now();
        $candidates = collect();
        foreach ($this->subscriptions()->whereNull('cancelled_at')->where('starts_at', '<=', $now)->where('ends_at', '>', $now)->get() as $s) {
            $candidates->push(['package' => $s->package, 'source' => 'subscription', 'ends_at' => $s->ends_at]);
        }
        foreach ($this->grants()->whereNull('revoked_at')->where('starts_at', '<=', $now)->where('ends_at', '>', $now)->get() as $g) {
            $candidates->push(['package' => $g->package, 'source' => 'beta', 'ends_at' => $g->ends_at]);
        }
        $rank = fn ($p) => config("goyana.packages.$p.rank", 0);
        $best = $candidates->sort(fn ($a, $b) => [$rank($b['package']), $b['ends_at']->getTimestamp()] <=> [$rank($a['package']), $a['ends_at']->getTimestamp()])->first();
        // Akun uji pemilik GOYANA (config goyana.full_access): selalu paket tertinggi, tanpa masa berakhir.
        $full = (array) config('goyana.full_access.emails');
        if ($full && $this->users()->where('role', 'owner')->whereNull('deactivated_at')->whereIn('email', $full)->exists()) {
            return $this->accessFor((string) config('goyana.full_access.package'), 'beta', $now->toImmutable()->addYears(10), false);
        }
        if ($best) return $this->accessFor($best['package'], $best['source'], $best['ends_at'], false);
        if ($this->trial_ends_at->isFuture()) {
            return $this->accessFor(config('goyana.trial.package'), 'trial', $this->trial_ends_at, false);
        }
        // Expired: keep the last entitlement end for the retention countdown.
        $lastEnd = collect([
            $this->trial_ends_at,
            $this->subscriptions()->whereNull('cancelled_at')->max('ends_at'),
            $this->grants()->whereNull('revoked_at')->max('ends_at'),
        ])->filter()->map(fn ($d) => \Carbon\CarbonImmutable::parse($d))->max();
        return $this->accessFor(null, 'expired', $lastEnd, true);
    }

    private function accessFor(?string $package, string $source, $endsAt, bool $readOnly): array {
        $branches = $package ? (int) config("goyana.packages.$package.branches", 0) : 0;
        return [
            'package' => $package, 'source' => $source, 'ends_at' => $endsAt, 'read_only' => $readOnly,
            'branches' => $branches,
            // 1 outlet pusat + cabang paket. Read-only keeps existing outlets visible but allows no new ones.
            'outlet_limit' => $readOnly ? $this->outlets()->count() : 1 + $branches,
            // HP kasir per outlet mengikuti paket (keputusan pengguna 8 Oktober 2026).
            'cashier_device_limit' => (int) ($package ? config("goyana.packages.$package.cashier_devices") : null) ?: (int) config('goyana.cashier_devices_per_outlet'),
        ];
    }
}
