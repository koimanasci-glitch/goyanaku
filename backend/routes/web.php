<?php
use App\Http\Controllers\{AuthController, AdminController, DashboardController, DeviceController};
use Illuminate\Support\Facades\Route;
Route::redirect('/', '/dashboard');
Route::middleware('guest')->group(function () {
    Route::view('/login', 'auth', ['register' => false])->name('login');
    Route::view('/register', 'auth', ['register' => true])->name('register');
    Route::post('/login', [AuthController::class, 'login'])->middleware('throttle:login');
    Route::post('/register', [AuthController::class, 'register'])->middleware('throttle:registration');
});
Route::middleware('auth')->group(function () {
    Route::post('/logout', [AuthController::class, 'logout'])->name('logout');
    Route::get('/dashboard', DashboardController::class)->name('dashboard');
    Route::post('/outlets/{outlet}/devices', [DeviceController::class, 'store'])->name('devices.store');
    Route::post('/outlets/{outlet}/devices/{device}/revoke', [DeviceController::class, 'revoke'])->name('devices.revoke');
    Route::prefix('admin')->middleware('platform.admin')->group(function () {
        Route::get('/', [AdminController::class, 'index'])->name('admin.index');
        Route::get('/businesses/{business}', [AdminController::class, 'show'])->name('admin.business');
        Route::post('/businesses/{business}/grants', [AdminController::class, 'grant'])->name('admin.grant');
        Route::post('/businesses/{business}/grants/{grant}/revoke', [AdminController::class, 'revoke'])->name('admin.revoke');
    });
});
