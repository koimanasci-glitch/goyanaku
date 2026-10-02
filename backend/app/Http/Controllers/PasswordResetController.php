<?php
namespace App\Http\Controllers;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Password;
use Illuminate\Validation\Rules\Password as Rule;
use Illuminate\Validation\ValidationException;
class PasswordResetController {
    public function request() { return view('password-forgot'); }
    public function send(Request $request) {
        $request->merge(['email' => mb_strtolower(trim((string) $request->input('email')))]);
        $request->validate(['email' => 'required|email|max:254']);
        // Platform admins reset through the server terminal only.
        $user = User::where('email', $request->input('email'))->first();
        if ($user && !$user->is_platform_admin) Password::sendResetLink($request->only('email'));
        // Same answer whether the email exists or not (no account discovery).
        return back()->with('status', 'Jika email terdaftar, link reset password sudah dikirim. Cek kotak masuk / spam. Link berlaku 60 menit.');
    }
    public function edit(Request $request, string $token) { return view('password-reset', ['token' => $token, 'email' => (string) $request->query('email', '')]); }
    public function update(Request $request) {
        $request->merge(['email' => mb_strtolower(trim((string) $request->input('email')))]);
        $data = $request->validate(['token' => 'required|string', 'email' => 'required|email|max:254',
            'password' => ['required', 'confirmed', Rule::min(12)->letters()->numbers()]]);
        $status = Password::reset($data, function (User $user, string $password) {
            abort_if($user->is_platform_admin, 403);
            $user->password = $password; $user->setRememberToken(\Illuminate\Support\Str::random(60)); $user->save();
            $user->tokens()->delete(); // log out every phone/API session
        });
        if ($status !== Password::PASSWORD_RESET) throw ValidationException::withMessages(['email' => 'Link reset tidak valid atau sudah kedaluwarsa. Minta link baru.']);
        return redirect()->route('login')->with('status', 'Password diganti. Silakan masuk di aplikasi atau web dengan password baru.');
    }
}
