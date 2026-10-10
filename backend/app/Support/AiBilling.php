<?php
namespace App\Support;
use App\Models\Business;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;
/**
 * Saldo AI (GOYANA-SISTEM-PUSAT.md §44). Rupiah charged = real OpenRouter cost (USD)
 * × latest USD→IDR rate × (1 + cadangan kurs) × (1 + untung). Always rounded up; balance never negative.
 */
class AiBilling {
    public static function fxRate(): ?float {
        $rate = DB::table('fx_rates')->where('currency', 'USD')->orderByDesc('day')->value('rate');
        return $rate ? (float) $rate : null;
    }

    public static function toRupiah(float $costUsd): int {
        $fx = self::fxRate();
        if (!$fx) throw new \RuntimeException('Kurs USD belum tersedia. Jalankan goyana:fx-update.');
        $s = Settings::all();
        $rp = $costUsd * $fx * (1 + $s['fx_cushion_percent'] / 100) * (1 + $s['ai_margin_percent'] / 100);
        return max(1, (int) ceil(round($rp, 6)));
    }

    /** Manual top-up (transfer/QRIS checked by admin) until the payment gateway is live. Idempotent by reference. */
    public static function topUp(Business $business, int $amount, string $reference, ?int $actorId, string $type = 'topup'): int {
        if ($type === 'topup' && $amount < (int) Settings::get('ai_min_topup')) {
            throw ValidationException::withMessages(['amount' => 'Minimal top-up Rp'.number_format(Settings::get('ai_min_topup'), 0, ',', '.').'.']);
        }
        $balance = DB::transaction(function () use ($business, $amount, $reference, $actorId, $type) {
            $locked = Business::whereKey($business->id)->lockForUpdate()->firstOrFail();
            if (DB::table('ai_ledger')->where(['business_id' => $locked->id, 'type' => $type, 'reference' => $reference])->exists()) {
                throw ValidationException::withMessages(['reference' => 'Referensi ini sudah dicatat.']);
            }
            $balance = $locked->ai_balance + $amount;
            if ($balance < 0) throw ValidationException::withMessages(['amount' => 'Saldo tidak boleh minus.']);
            $locked->forceFill(['ai_balance' => $balance])->save();
            DB::table('ai_ledger')->insert(['business_id' => $locked->id, 'type' => $type, 'amount' => $amount, 'balance_after' => $balance,
                'reference' => $reference, 'actor_id' => $actorId, 'created_at' => now()]);
            DB::table('audit_events')->insert(['actor_id' => $actorId ?? $locked->users()->value('id'), 'business_id' => $locked->id, 'action' => 'ai.'.$type,
                'details' => json_encode(['amount' => $amount, 'reference' => $reference, 'balance' => $balance]), 'created_at' => now()]);
            return $balance;
        });
        // Chatbot AI WhatsApp berjalan di CHATKU (keputusan Paduka 10 Okt 2026): isi saldo diteruskan supaya saldo AI di CHATKU ikut terisi.
        if ($type === 'topup' && $amount > 0) \App\WhatsApp\Jobs\ForwardAiTopup::dispatchIfConnected($business->id, $amount, $reference);
        return $balance;
    }

    /**
     * Potong saldo dengan rupiah yang sudah dihitung pihak lain (AI WhatsApp lewat CHATKU: biaya asli × kurs (+2%) + untung 25%).
     * Sekali per referensi; saldo tidak pernah minus (bila kurang, dipotong sampai nol).
     */
    public static function debitRupiah(Business $business, int $rp, string $model, string $reference): int {
        if ($rp <= 0) return 0;
        return DB::transaction(function () use ($business, $rp, $model, $reference) {
            $locked = Business::whereKey($business->id)->lockForUpdate()->firstOrFail();
            $done = DB::table('ai_ledger')->where(['business_id' => $locked->id, 'type' => 'usage', 'reference' => $reference])->value('amount');
            if ($done !== null) return -$done;
            $take = min($rp, max(0, (int) $locked->ai_balance));
            $balance = (int) $locked->ai_balance - $take;
            $locked->forceFill(['ai_balance' => $balance])->save();
            DB::table('ai_ledger')->insert(['business_id' => $locked->id, 'type' => 'usage', 'amount' => -$take, 'balance_after' => $balance, 'reference' => $reference,
                'model' => mb_substr($model, 0, 100), 'created_at' => now()]);
            return $take;
        });
    }

    /**
     * Charge one AI request after it ran, using the cost OpenRouter reported. Same reference twice = charged once.
     * Returns the rupiah charged, or null when the balance is too low (caller must not have sent the request; see canAfford).
     */
    public static function charge(Business $business, float $costUsd, string $model, string $reference): ?int {
        $rp = self::toRupiah($costUsd); $fx = self::fxRate();
        return DB::transaction(function () use ($business, $costUsd, $model, $reference, $rp, $fx) {
            $locked = Business::whereKey($business->id)->lockForUpdate()->firstOrFail();
            $done = DB::table('ai_ledger')->where(['business_id' => $locked->id, 'type' => 'usage', 'reference' => $reference])->value('amount');
            if ($done !== null) return -$done;
            if ($locked->ai_balance < $rp) return null;
            $balance = $locked->ai_balance - $rp;
            $locked->forceFill(['ai_balance' => $balance])->save();
            DB::table('ai_ledger')->insert(['business_id' => $locked->id, 'type' => 'usage', 'amount' => -$rp, 'balance_after' => $balance, 'reference' => $reference,
                'model' => $model, 'cost_usd' => $costUsd, 'fx_rate' => $fx, 'created_at' => now()]);
            return $rp;
        });
    }

    /** Pre-check before calling the AI: estimated cost of a request with this many tokens on the model. */
    public static function canAfford(Business $business, string $model, int $promptTokens, int $maxCompletionTokens): bool {
        $m = DB::table('ai_models')->where('id', $model)->where('available', true)->first();
        if (!$m) return false;
        $usd = ($promptTokens * $m->prompt_usd_per_mtok + $maxCompletionTokens * $m->completion_usd_per_mtok) / 1_000_000;
        return $business->fresh()->ai_balance >= self::toRupiah($usd);
    }
}
