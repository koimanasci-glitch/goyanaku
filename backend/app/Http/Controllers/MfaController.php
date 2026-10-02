<?php
namespace App\Http\Controllers;

use App\Support\Totp;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/** OTP (authenticator app) for platform administrators — GOYANA-SISTEM-PUSAT.md §9. */
class MfaController {
    public function setup(Request $request) {
        $user = $request->user();
        if ($user->mfa_confirmed_at) return redirect()->route('admin.mfa');
        $secret = $request->session()->get('mfa_pending_secret') ?: Totp::secret();
        $request->session()->put('mfa_pending_secret', $secret);
        return view('mfa', ['setup' => true, 'secret' => $secret, 'uri' => Totp::uri($secret, $user->email)]);
    }

    public function confirm(Request $request) {
        $user = $request->user();
        $secret = (string) $request->session()->get('mfa_pending_secret');
        $data = $request->validate(['code' => 'required|string|max:10']);
        $step = $secret ? Totp::verify($secret, $data['code']) : null;
        if ($step === null) throw ValidationException::withMessages(['code' => 'Kode OTP tidak sesuai.']);
        DB::transaction(function () use ($user, $secret, $step) {
            $user->mfa_secret = $secret; $user->mfa_confirmed_at = now(); $user->mfa_last_step = $step; $user->save();
        });
        $request->session()->forget('mfa_pending_secret');
        $request->session()->regenerate();
        $request->session()->put('mfa_passed_for', $user->id);
        return redirect()->route('admin.index')->with('status', 'OTP aktif. Simpan aplikasi authenticator Anda.');
    }

    public function challenge(Request $request) {
        if (!$request->user()->mfa_confirmed_at) return redirect()->route('admin.mfa.setup');
        return view('mfa', ['setup' => false]);
    }

    public function verify(Request $request) {
        $user = $request->user();
        $data = $request->validate(['code' => 'required|string|max:10']);
        $step = $user->mfa_secret ? Totp::verify($user->mfa_secret, $data['code']) : null;
        // Reject wrong codes and reuse of an already accepted code.
        if ($step === null || ($user->mfa_last_step !== null && $step <= $user->mfa_last_step)) {
            throw ValidationException::withMessages(['code' => 'Kode OTP tidak sesuai.']);
        }
        $user->mfa_last_step = $step; $user->save();
        $request->session()->regenerate();
        $request->session()->put('mfa_passed_for', $user->id);
        return redirect()->intended(route('admin.index'));
    }
}
