<?php
namespace App\WhatsApp\Http;

use App\Support\QrisGuard;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\{Cache, DB, Hash, Mail};

/**
 * Buka kunci ganti QRIS 10 menit: password akun pemilik, atau kode 6 angka ke email pemilik (akun masuk Google).
 * Hanya pemilik usaha; staf selalu ditolak.
 */
final class QrisController {
    private function owner(Request $r) {
        $u = $r->user();
        abort_unless($u && $u->isOwner(), 403, 'QRIS hanya bisa diganti pemilik usaha.');
        return $u;
    }

    public function code(Request $r) {
        $u = $this->owner($r);
        $code = (string) random_int(100000, 999999);
        Cache::put('qris-code:'.$u->id, Hash::make($code), now()->addMinutes(10));
        $body = "Kode konfirmasi ganti QRIS: $code\nBerlaku 10 menit. Jangan berikan kode ini kepada siapa pun, termasuk yang mengaku dari GOYANA.\n\nBila Anda tidak sedang mengganti QRIS, abaikan email ini dan segera ganti password akun.";
        DB::table('outbound_messages')->insert(['business_id' => $u->business_id, 'kind' => 'qris_code', 'dedupe_key' => 'qris-code:'.$u->id.':'.now()->format('YmdHis').random_int(10, 99),
            'channel' => 'email', 'recipient' => $u->email, 'subject' => 'Kode konfirmasi ganti QRIS', 'body' => 'Kode konfirmasi ganti QRIS (disembunyikan)', 'status' => 'sent', 'created_at' => now()]);
        try { Mail::raw($body, fn ($m) => $m->to($u->email)->subject('Kode konfirmasi ganti QRIS')); }
        catch (\Throwable) { abort(503, 'Email belum bisa dikirim. Pakai password akun.'); }
        return response()->json(['sent' => true, 'email' => preg_replace('/(?<=.).(?=[^@]*@)/', '•', $u->email)]);
    }

    public function unlock(Request $r) {
        $u = $this->owner($r);
        $v = $r->validate(['password' => 'nullable|string|max:200', 'code' => 'nullable|digits:6']);
        $ok = false;
        if (!empty($v['code'])) {
            $hash = Cache::get('qris-code:'.$u->id);
            $ok = is_string($hash) && Hash::check($v['code'], $hash);
            if ($ok) Cache::forget('qris-code:'.$u->id);
        } elseif (!empty($v['password']) && $u->password) {
            $ok = Hash::check($v['password'], $u->password);
        }
        abort_unless($ok, 422, !empty($v['code']) ? 'Kode salah atau kedaluwarsa.' : 'Password salah.');
        DB::table('audit_events')->insert(['actor_id' => $u->id, 'business_id' => $u->business_id, 'action' => 'qris.unlock',
            'details' => json_encode(['via' => !empty($v['code']) ? 'email' : 'password']), 'created_at' => now()]);
        return response()->json(['until' => QrisGuard::unlock($u), 'minutes' => QrisGuard::MINUTES]);
    }
}
