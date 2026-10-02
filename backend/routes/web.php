<?php
use App\Http\Controllers\{AuthController, AdminController, DashboardController, DeviceController, MfaController, OutletController, TeamController};
use Illuminate\Foundation\Auth\EmailVerificationRequest;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

Route::redirect('/', '/dashboard');
Route::middleware('guest')->group(function () {
    Route::view('/login', 'auth', ['register' => false])->name('login');
    Route::view('/register', 'auth', ['register' => true])->name('register');
    Route::post('/login', [AuthController::class, 'login'])->middleware('throttle:login');
    Route::post('/register', [AuthController::class, 'register'])->middleware('throttle:registration');
});

Route::middleware(['auth', 'active'])->group(function () {
    Route::post('/logout', [AuthController::class, 'logout'])->name('logout');

    // Email verification (enforced when GOYANA_REQUIRE_EMAIL_VERIFICATION=true).
    Route::view('/email/verify', 'verify')->name('verification.notice');
    Route::get('/email/verify/{id}/{hash}', function (EmailVerificationRequest $request) {
        $request->fulfill();
        return redirect()->route('dashboard')->with('status', 'Email terverifikasi.');
    })->middleware('signed')->name('verification.verify');
    Route::post('/email/verification-notification', function (Request $request) {
        $request->user()->sendEmailVerificationNotification();
        return back()->with('status', 'Link verifikasi dikirim ulang.');
    })->middleware('throttle:6,1')->name('verification.send');

    Route::middleware('verified.required')->group(function () {
        Route::get('/dashboard', DashboardController::class)->name('dashboard');
        Route::middleware('owner')->group(function () {
            Route::post('/outlets', [OutletController::class, 'store'])->name('outlets.store');
            Route::post('/outlets/{outlet}/devices', [DeviceController::class, 'store'])->name('devices.store');
            Route::post('/outlets/{outlet}/devices/{device}/revoke', [DeviceController::class, 'revoke'])->name('devices.revoke');
            Route::post('/team', [TeamController::class, 'store'])->name('team.store');
            Route::post('/team/{member}', [TeamController::class, 'update'])->name('team.update');
            Route::post('/team/{member}/deactivate', [TeamController::class, 'deactivate'])->name('team.deactivate');
            Route::post('/team/{member}/activate', [TeamController::class, 'activate'])->name('team.activate');
            Route::post('/team/{member}/password', [TeamController::class, 'resetPassword'])->name('team.password');
        });
    });

    Route::prefix('admin')->group(function () {
        Route::middleware('platform.admin:password')->group(function () {
            Route::get('/mfa/setup', [MfaController::class, 'setup'])->name('admin.mfa.setup');
            Route::post('/mfa/setup', [MfaController::class, 'confirm'])->middleware('throttle:login');
            Route::get('/mfa', [MfaController::class, 'challenge'])->name('admin.mfa');
            Route::post('/mfa', [MfaController::class, 'verify'])->middleware('throttle:login');
        });
        Route::middleware('platform.admin')->group(function () {
            Route::get('/', [AdminController::class, 'index'])->name('admin.index');
            Route::get('/businesses/{business}', [AdminController::class, 'show'])->name('admin.business');
            Route::post('/businesses/{business}/grants', [AdminController::class, 'grant'])->name('admin.grant');
            Route::post('/businesses/{business}/grants/{grant}/revoke', [AdminController::class, 'revoke'])->name('admin.revoke');
            Route::post('/businesses/{business}/subscriptions', [AdminController::class, 'subscribe'])->name('admin.subscribe');
            Route::post('/businesses/{business}/subscriptions/{subscription}/cancel', [AdminController::class, 'cancelSubscription'])->name('admin.subscription.cancel');
            Route::post('/businesses/{business}/devices/{device}/revoke', [AdminController::class, 'revokeDevice'])->name('admin.device.revoke');
            Route::get('/audit', [AdminController::class, 'audit'])->name('admin.audit');
            Route::get('/system', [AdminController::class, 'system'])->name('admin.system');
        });
    });
});
