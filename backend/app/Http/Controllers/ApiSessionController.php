<?php
namespace App\Http\Controllers;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

class ApiSessionController {
    public function login(Request $request) {
        $data = $request->validate(['email' => 'required|string|max:254', 'password' => 'required|string|max:1024']);
        $user = User::where('email', mb_strtolower(trim($data['email'])))->first();
        if (!$user || !Hash::check($data['password'], $user->password) || $user->is_platform_admin || !$user->business_id) {
            throw ValidationException::withMessages(['email' => 'Email atau password tidak sesuai.']);
        }
        if (!$user->isActive()) {
            throw ValidationException::withMessages(['email' => 'Akun dinonaktifkan. Hubungi owner usaha.']);
        }
        $user->tokens()->where('expires_at', '<=', now())->delete();
        $expires = now()->addDay();
        // Token abilities mirror the role, so the server rejects actions the role may not do.
        $abilities = array_values(array_unique(array_merge(['business:read'], $user->permissions())));
        return response()->json([
            'token' => $user->createToken('android-'.$user->role, $abilities, $expires)->plainTextToken,
            'expires_at' => $expires->toIso8601String(),
        ]);
    }

    public function me(Request $request) {
        $user = $request->user();
        abort_if($user->is_platform_admin || !$user->business_id, 403);
        abort_unless($user->isActive(), 403, 'Akun dinonaktifkan.');
        abort_unless($user->tokenCan('business:read'), 403);
        $business = $user->business;
        $access = $business->currentAccess();
        $outlets = $business->outlets()->get(['id', 'business_id', 'name'])
            ->filter(fn ($o) => $user->canAccessOutlet($o))->map(fn ($o) => ['id' => $o->id, 'name' => $o->name])->values();
        return response()->json([
            'user' => ['name' => $user->name, 'role' => $user->role, 'role_label' => $user->roleLabel(), 'permissions' => $user->permissions()],
            'business' => ['id' => $business->id, 'name' => $business->name],
            'access' => [
                'package' => $access['package'], 'source' => $access['source'], 'read_only' => $access['read_only'],
                'ends_at' => $access['ends_at']?->toIso8601String(), 'outlet_limit' => $access['outlet_limit'],
            ],
            'outlets' => $outlets,
        ]);
    }

    public function logout(Request $request) {
        $token = $request->user()->currentAccessToken();
        abort_unless($token instanceof \Laravel\Sanctum\PersonalAccessToken, 403);
        $token->delete();
        return response()->noContent();
    }
}
