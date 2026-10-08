<?php
use App\Http\Controllers\{AuthController, PasswordResetController, AdminController, AdminSupportController, AdminFaqController, AdminAssistController, SupportController, DashboardController, DeviceController, MonitoringController, MfaController, OutletController, TeamController};
use Illuminate\Foundation\Auth\EmailVerificationRequest;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

Route::redirect('/', '/dashboard');
Route::middleware('guest')->group(function () {
    Route::view('/login', 'auth', ['register' => false])->name('login');
    Route::view('/register', 'auth', ['register' => true])->name('register');
    Route::post('/login', [AuthController::class, 'login'])->middleware('throttle:login');
    Route::post('/register', [AuthController::class, 'register'])->middleware('throttle:registration');
    Route::get('/forgot-password', [PasswordResetController::class, 'request'])->name('password.request');
    Route::post('/forgot-password', [PasswordResetController::class, 'send'])->middleware('throttle:5,10')->name('password.email');
    Route::get('/reset-password/{token}', [PasswordResetController::class, 'edit'])->name('password.reset');
    Route::post('/reset-password', [PasswordResetController::class, 'update'])->middleware('throttle:10,10')->name('password.update');
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
        Route::get('/monitoring', MonitoringController::class)->name('monitoring');
        Route::get('/support', [SupportController::class, 'index'])->name('support');
        Route::post('/support', [SupportController::class, 'store'])->middleware('throttle:20,60')->name('support.store');
        Route::get('/support/{ticket}', [SupportController::class, 'show'])->name('support.show');
        Route::post('/support-assist', [SupportController::class, 'allowAssist'])->name('support.assist');
        Route::post('/support-assist/stop', [SupportController::class, 'revokeAssist'])->name('support.assist.stop');
        Route::post('/support/{ticket}', [SupportController::class, 'reply'])->middleware('throttle:60,60')->name('support.reply');
        Route::middleware('owner')->group(function () {
            Route::post('/outlets', [OutletController::class, 'store'])->name('outlets.store');
            Route::post('/outlets/{outlet}', [OutletController::class, 'update'])->whereNumber('outlet')->name('outlets.update');
            Route::post('/outlets/{outlet}/deactivate', [OutletController::class, 'deactivate'])->name('outlets.deactivate');
            Route::post('/outlets/{outlet}/activate', [OutletController::class, 'activate'])->name('outlets.activate');
            Route::post('/shared-devices/{device}/revoke', [OutletController::class, 'revokeShared'])->name('shared.revoke');
            Route::post('/business/settings', [OutletController::class, 'settings'])->name('business.settings');
            Route::post('/outlets/{outlet}/devices', [DeviceController::class, 'store'])->name('devices.store');
            Route::post('/outlets/{outlet}/devices/{device}/revoke', [DeviceController::class, 'revoke'])->name('devices.revoke');
            Route::post('/team', [TeamController::class, 'store'])->name('team.store');
            Route::post('/team/{member}', [TeamController::class, 'update'])->name('team.update');
            Route::post('/team/{member}/deactivate', [TeamController::class, 'deactivate'])->name('team.deactivate');
            Route::post('/team/{member}/activate', [TeamController::class, 'activate'])->name('team.activate');
            Route::post('/team/{member}/password', [TeamController::class, 'resetPassword'])->name('team.password');
            Route::post('/team/{member}/pin', [TeamController::class, 'resetPin'])->name('team.pin');
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
            Route::post('/businesses/{business}/ai-topup', [AdminController::class, 'aiTopUp'])->name('admin.ai.topup');
            Route::post('/businesses/{business}/quick-reply-test', [AdminController::class, 'quickReplyTest'])->name('admin.qr.test');
            Route::get('/businesses/{business}/assist', [AdminAssistController::class, 'show'])->name('admin.assist');
            Route::post('/businesses/{business}/assist/service', [AdminAssistController::class, 'saveService'])->name('admin.assist.service');
            Route::post('/businesses/{business}/assist/outlet', [AdminAssistController::class, 'saveOutlet'])->name('admin.assist.outlet');
            Route::post('/businesses/{business}/assist/revert/{event}', [AdminAssistController::class, 'revert'])->whereNumber('event')->name('admin.assist.revert');
            Route::get('/audit', [AdminController::class, 'audit'])->name('admin.audit');
            Route::get('/system', [AdminController::class, 'system'])->name('admin.system');
            Route::get('/tickets', [AdminSupportController::class, 'index'])->name('admin.tickets');
            Route::get('/tickets/{ticket}', [AdminSupportController::class, 'show'])->name('admin.ticket');
            Route::post('/tickets/{ticket}/reply', [AdminSupportController::class, 'reply'])->name('admin.ticket.reply');
            Route::post('/tickets/{ticket}', [AdminSupportController::class, 'update'])->name('admin.ticket.update');
            Route::get('/faqs', [AdminFaqController::class, 'index'])->name('admin.faqs');
            Route::post('/faqs', [AdminFaqController::class, 'store'])->name('admin.faqs.store');
            Route::post('/faqs/{faq}', [AdminFaqController::class, 'update'])->whereNumber('faq')->name('admin.faqs.update');
            Route::post('/faqs/{faq}/delete', [AdminFaqController::class, 'destroy'])->whereNumber('faq')->name('admin.faqs.delete');
            Route::get('/settings', [AdminSupportController::class, 'settings'])->name('admin.settings');
            Route::post('/settings', [AdminSupportController::class, 'saveSettings'])->name('admin.settings.save');
        });
    });
});
