<?php
use App\Http\Controllers\{ApiMonitoringController, ApiOutletController, ApiSessionController, ApiTeamController, SyncController};
use Illuminate\Support\Facades\Route;

Route::post('/session', [ApiSessionController::class, 'login'])->middleware('throttle:login');
Route::post('/session/pin', [ApiSessionController::class, 'loginPin'])->middleware('throttle:pin');
Route::post('/session/google', [ApiSessionController::class, 'google'])->middleware('throttle:login');
// Yang perlu diketahui layar masuk aplikasi sebelum ada sesi: apakah masuk Google aktif dan Client ID-nya.
Route::get('/session/options', fn () => response()->json(['google' => ['client_ids' => (array) config('goyana.google.client_ids')], 'pin_length' => (int) config('goyana.pin.length')]));
Route::post('/devices/roster', [ApiSessionController::class, 'roster'])->middleware('throttle:pin');

Route::middleware(['auth:sanctum', 'active', 'throttle:api'])->group(function () {
    Route::get('/me', [ApiSessionController::class, 'me']);
    Route::delete('/session', [ApiSessionController::class, 'logout']);
    Route::post('/me/pin', [ApiSessionController::class, 'changePin']);
    Route::post('/me/password', [ApiSessionController::class, 'changePassword']);
    Route::post('/devices/claim', [ApiSessionController::class, 'claimDevice']);
    Route::get('/sync/pull', [SyncController::class, 'pull']);
    Route::post('/sync/push', [SyncController::class, 'push'])->middleware('throttle:sync');

    // Monitoring: laporan lengkap untuk owner (admin outlet: outletnya sendiri); yang lain ringkasan milik sendiri.
    Route::get('/monitoring', [ApiMonitoringController::class, 'report']);
    Route::get('/monitoring/alerts', [ApiMonitoringController::class, 'alerts']);
    Route::get('/me/summary', [ApiMonitoringController::class, 'own']);
    // Riwayat Transaksi per nota dan laporan Koreksi Transaksi (10 Okt 2026).
    Route::get('/orders/{key}/history', [\App\Http\Controllers\ApiOrderHistoryController::class, 'history'])->where('key', '[A-Za-z0-9._:-]{1,160}');
    Route::get('/corrections', [\App\Http\Controllers\ApiOrderHistoryController::class, 'corrections']);
    // Tunai kurir: dipegang kurir sampai disetor ke kasir outletnya.
    Route::get('/courier/cash', [ApiMonitoringController::class, 'courierOwn']);
    Route::get('/courier-cash', [ApiMonitoringController::class, 'courierCash']);
    Route::post('/courier-cash/{courier}/deposit', [ApiMonitoringController::class, 'deposit'])->whereNumber('courier');

    // Kelola Cabang, Kelola Pegawai, HP outlet, setelan usaha: hanya owner.
    Route::middleware('owner')->group(function () {
        Route::get('/team', [ApiTeamController::class, 'index']);
        Route::post('/team', [ApiTeamController::class, 'store']);
        Route::patch('/team/{member}', [ApiTeamController::class, 'update'])->whereNumber('member');
        Route::post('/team/{member}/pin', [ApiTeamController::class, 'pin'])->whereNumber('member');
        Route::post('/team/{member}/password', [ApiTeamController::class, 'password'])->whereNumber('member');
        Route::post('/team/{member}/deactivate', [ApiTeamController::class, 'deactivate'])->whereNumber('member');
        Route::post('/team/{member}/activate', [ApiTeamController::class, 'activate'])->whereNumber('member');
        Route::get('/outlets', [ApiOutletController::class, 'index']);
        Route::post('/outlets', [ApiOutletController::class, 'store']);
        Route::patch('/outlets/{outlet}', [ApiOutletController::class, 'update'])->whereNumber('outlet');
        Route::post('/outlets/{outlet}/deactivate', [ApiOutletController::class, 'deactivate'])->whereNumber('outlet');
        Route::post('/outlets/{outlet}/activate', [ApiOutletController::class, 'activate'])->whereNumber('outlet');
        Route::get('/devices', [ApiOutletController::class, 'devices']);
        Route::post('/devices/shared', [ApiOutletController::class, 'bindShared']);
        Route::delete('/devices/shared/{device}', [ApiOutletController::class, 'revokeShared'])->whereNumber('device');
        Route::delete('/devices/cashier/{device}', [ApiOutletController::class, 'revokeCashier'])->whereNumber('device');
        Route::patch('/business', [ApiOutletController::class, 'business']);
    });
});
