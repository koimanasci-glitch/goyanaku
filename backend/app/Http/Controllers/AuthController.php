<?php
namespace App\Http\Controllers;
use App\Models\Business;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rules\Password;
use Illuminate\Validation\ValidationException;
class AuthController {
    public function register(Request $request) {
        $request->merge(['email' => mb_strtolower(trim((string) $request->input('email')))]);
        $data = $request->validate([
            'name' => 'required|string|max:120', 'business_name' => 'required|string|max:120',
            'email' => 'required|email|max:254|unique:users,email',
            'password' => ['required', 'confirmed', Password::min(12)->letters()->numbers()],
        ]);
        $user = DB::transaction(function () use ($data) {
            $business = Business::create(['name' => $data['business_name'], 'trial_ends_at' => now()->addMonthsNoOverflow(2)]);
            $business->outlets()->create(['name' => $data['business_name'].' — Pusat']);
            $user = new User(collect($data)->only(['name', 'email', 'password'])->all());
            $user->business()->associate($business);
            $user->save();
            return $user;
        });
        Auth::login($user); $request->session()->regenerate();
        return redirect()->route('dashboard');
    }
    public function login(Request $request) {
        $data = $request->validate(['email' => 'required|string|max:254', 'password' => 'required|string|max:1024']);
        $data['email'] = mb_strtolower(trim($data['email']));
        if (!Auth::attempt($data)) throw ValidationException::withMessages(['email' => 'Email atau password tidak sesuai.']);
        $request->session()->regenerate();
        return redirect()->route($request->user()->is_platform_admin ? 'admin.index' : 'dashboard');
    }
    public function logout(Request $request) {
        Auth::logout(); $request->session()->invalidate(); $request->session()->regenerateToken();
        return redirect()->route('login');
    }
}
