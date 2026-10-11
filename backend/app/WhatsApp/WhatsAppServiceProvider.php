<?php
namespace App\WhatsApp;
use App\WhatsApp\Contracts\ChatkuGateway;
use App\WhatsApp\Http\{ChatbotController,DeviceController,WebhookController,TemplateController};
use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\ServiceProvider;

/** Terdaftar di bootstrap/providers.php sejak aba-aba Paduka 8 Oktober 2026. API perangkat dan webhook tetap menunggu GOYANA_WHATSAPP_ENABLED. */
final class WhatsAppServiceProvider extends ServiceProvider {
    public function register(): void {
        $this->mergeConfigFrom(__DIR__.'/config.php','whatsapp');
        // Adapter resmi CHATKU hanya bila kunci API mitra diisi di .env server; tanpa itu tetap 503 (tidak ada QR/status palsu).
        if(!$this->app->bound(ChatkuGateway::class)){
            $this->app->singleton(ChatkuGateway::class,function(){
                $c=(array)config('whatsapp.chatku',[]);
                return ($c['api_key']??'')!=='' ? new ChatkuHttpGateway(new Chatku\Client($c),$c) : new UnavailableGateway;
            });
        }
    }
    public function boot(): void {
        $this->loadMigrationsFrom(__DIR__.'/database');
        $this->loadViewsFrom(__DIR__.'/views','whatsapp');
        $this->commands([RetryOutbox::class,Console\AutoMessagesCommand::class,Console\QrisWatchCommand::class,Console\PruneCommand::class]);
        $this->callAfterResolving(Schedule::class,function(Schedule $s){
            // Pengaman QRIS berjalan untuk semua usaha, terlepas dari modul WhatsApp.
            $s->command('goyana:qris-watch')->everyFiveMinutes()->withoutOverlapping();
            if(!config('whatsapp.enabled'))return;
            $s->command('goyana:wa-auto')->everyFiveMinutes()->withoutOverlapping();
            $s->command('goyana:wa-prune')->hourly()->withoutOverlapping();
        });
        // Link bertanda tangan & kedaluwarsa: nota digital pelanggan dan berkas media untuk CHATKU / pratinjau aplikasi.
        Route::middleware(['web','signed','throttle:60,1'])->get('wa/nota',[ChatbotController::class,'nota'])->name('wa.nota');
        Route::middleware(['signed','throttle:120,1'])->get('wa/media/{id}',[ChatbotController::class,'file'])->name('wa.media');
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
            // Chatbot per cabang (balasan cepat, AI/knowledge, pesan otomatis), media (maks. 10/cabang), blast.
            Route::get('chatbot/{outlet}',[ChatbotController::class,'show'])->whereNumber('outlet');
            Route::put('chatbot/{outlet}',[ChatbotController::class,'save'])->whereNumber('outlet');
            Route::post('chatbot/{outlet}/replies',[ChatbotController::class,'saveReply'])->whereNumber('outlet');
            Route::delete('chatbot/replies/{id}',[ChatbotController::class,'deleteReply']);
            Route::post('chatbot/{outlet}/resume',[ChatbotController::class,'resume'])->whereNumber('outlet');
            Route::post('chatbot/{outlet}/ai-test',[ChatbotController::class,'aiTest'])->whereNumber('outlet')->middleware('throttle:10,1');
            Route::get('chatbot/{outlet}/media',[ChatbotController::class,'media'])->whereNumber('outlet');
            Route::post('chatbot/{outlet}/media',[ChatbotController::class,'upload'])->whereNumber('outlet')->middleware('throttle:20,1');
            Route::put('media/{id}',[ChatbotController::class,'renameMedia']);
            Route::delete('media/{id}',[ChatbotController::class,'deleteMedia']);
            Route::post('media/{id}/copy',[ChatbotController::class,'copyMedia']);
            Route::get('blasts',[ChatbotController::class,'blasts']);
            Route::get('blasts/audience',[ChatbotController::class,'audience']);
            Route::post('blasts',[ChatbotController::class,'createBlast'])->middleware('throttle:5,1');
            Route::get('blasts/{id}',[ChatbotController::class,'blast']);
            Route::post('blasts/{id}/cancel',[ChatbotController::class,'cancelBlast']);
        });
        // Semua event CHATKU datang dari satu IP: batas longgar, gerbang sesungguhnya tanda tangan HMAC.
        Route::middleware(['api','throttle:3000,1'])->post('api/whatsapp/chatku/events',WebhookController::class);
    }
}
