<?php
namespace App\WhatsApp;
use App\WhatsApp\Contracts\ChatkuGateway;
use App\WhatsApp\Http\{DeviceController,WebhookController,TemplateController};
use Illuminate\Support\Facades\Route;
use Illuminate\Support\ServiceProvider;

/** Terdaftar di bootstrap/providers.php sejak aba-aba Paduka 8 Oktober 2026. API perangkat dan webhook tetap menunggu GOYANA_WHATSAPP_ENABLED. */
final class WhatsAppServiceProvider extends ServiceProvider {
    public function register(): void {
        $this->mergeConfigFrom(__DIR__.'/config.php','whatsapp');
        if(!$this->app->bound(ChatkuGateway::class)) $this->app->bind(ChatkuGateway::class,UnavailableGateway::class);
    }
    public function boot(): void {
        $this->loadMigrationsFrom(__DIR__.'/database');
        $this->loadViewsFrom(__DIR__.'/views','whatsapp');
        $this->commands([RetryOutbox::class]);
        // Template pusat selalu tersedia bagi administrator (divisi CS/Bantuan dan pemilik); isinya baru dipakai saat balasan aktif.
        Route::middleware(['web','auth','active','platform.admin','admin.area:support'])->prefix('admin/whatsapp')->group(function(){
            Route::get('templates',[TemplateController::class,'index'])->name('admin.wa.templates');
            Route::post('templates',[TemplateController::class,'save'])->name('admin.wa.templates.save');
            Route::post('templates/preview',[TemplateController::class,'preview'])->name('admin.wa.templates.preview');
            Route::get('templates/{id}/revisions',[TemplateController::class,'revisions'])->whereNumber('id')->name('admin.wa.templates.revisions');
            Route::post('templates/propose',[TemplateController::class,'propose'])->middleware('throttle:2,60')->name('admin.wa.templates.propose');
        });
        if(!config('whatsapp.enabled'))return;
        Route::middleware(['api','auth:sanctum','active','throttle:30,1'])->prefix('api/whatsapp')->group(function(){
            Route::get('devices',[DeviceController::class,'index']);
            Route::post('devices',[DeviceController::class,'store']);
            Route::put('devices/{id}',[DeviceController::class,'update'])->whereUuid('id');
            Route::delete('devices/{id}',[DeviceController::class,'destroy'])->whereUuid('id');
            Route::post('devices/{id}/pairing',[DeviceController::class,'connect'])->whereUuid('id');
            Route::post('devices/{id}/refresh',[DeviceController::class,'refresh'])->whereUuid('id');
            Route::put('devices/{id}/automation',[DeviceController::class,'automation'])->whereUuid('id');
        });
        Route::middleware(['api','throttle:120,1'])->post('api/whatsapp/chatku/events',WebhookController::class);
    }
}
