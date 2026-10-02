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
        $user->tokens()->where('expires_at', '<=', now())->delete();
        $expires = now()->addDay();
        return response()->json(['token' => $user->createToken('flutter-owner-read', ['business:read'], $expires)->plainTextToken, 'expires_at' => $expires->toIso8601String()]);
    }
    public function me(Request $request) {
        $user = $request->user();
        abort_if($user->is_platform_admin || !$user->business_id, 403);
        abort_unless($user->tokenCan('business:read'), 403);
        $business = $user->business;
        $access = $business->currentAccess();
        return response()->json([
            'user' => ['name' => $user->name],
            'business' => ['id' => $business->id, 'name' => $business->name],
            'access' => ['package' => $access['package'], 'source' => $access['source'], 'read_only' => $access['read_only'], 'ends_at' => $access['ends_at']->toIso8601String()],
            'outlets' => $business->outlets()->get(['id', 'name']),
        ]);
    }
    public function logout(Request $request) {
        $token = $request->user()->currentAccessToken();
        abort_unless($token instanceof \Laravel\Sanctum\PersonalAccessToken, 403);
        $token->delete();
        return response()->noContent();
    }
}
