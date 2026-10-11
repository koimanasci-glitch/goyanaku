<?php
namespace App\WhatsApp;

use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\{DB, Storage, URL};
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

/**
 * Media balasan per cabang (keputusan Paduka 10 Okt 2026): maks. 10 berkas per cabang, foto dikompres jadi JPG ±300 KB
 * (sisi terpanjang 1600 px), PDF maks. 2 MB. Hapus = berkas di server ikut terhapus. Bisa disalin ke cabang lain.
 * Disimpan privat (bukan folder publik); CHATKU mengambil lewat link bertanda tangan yang kedaluwarsa.
 */
final class Media {
    private const DISK = 'local';

    public static function list(int $businessId, int $outletId): array {
        return DB::table('wa_media')->where(['business_id' => $businessId, 'outlet_id' => $outletId])->orderBy('created_at')->get()
            ->map(fn ($m) => self::present($m))->all();
    }

    public static function present(object $m): array {
        return ['id' => $m->id, 'outlet_id' => (int) $m->outlet_id, 'name' => $m->name, 'kind' => $m->kind, 'mime' => $m->mime, 'bytes' => (int) $m->bytes,
            'version' => (int) $m->version, 'preview_url' => self::link($m, 30), 'created_at' => (string) $m->created_at];
    }

    public static function find(int $businessId, string $id): object {
        abort_unless(Str::isUuid($id), 404);
        return DB::table('wa_media')->where(['id' => $id, 'business_id' => $businessId])->first() ?? abort(404, 'Media tidak ditemukan.');
    }

    public static function limit(): int { return (int) config('whatsapp.media.per_outlet', 10); }

    public static function store(int $businessId, int $outletId, UploadedFile $file, string $name): object {
        [$bytes, $kind, $mime] = self::prepare($file);
        return DB::transaction(function () use ($businessId, $outletId, $bytes, $kind, $mime, $name) {
            \App\Models\Business::whereKey($businessId)->lockForUpdate()->firstOrFail();
            self::assertRoom($businessId, $outletId);
            return self::insert($businessId, $outletId, $bytes, $kind, $mime, $name);
        });
    }

    private static function assertRoom(int $businessId, int $outletId): void {
        if (DB::table('wa_media')->where(['business_id' => $businessId, 'outlet_id' => $outletId])->count() >= self::limit()) {
            throw ValidationException::withMessages(['file' => 'Media cabang ini sudah '.self::limit().'. Hapus yang tidak dipakai dulu.']);
        }
    }

    private static function insert(int $businessId, int $outletId, string $bytes, string $kind, string $mime, string $name): object {
        $id = (string) Str::uuid();
        $path = "wa-media/$businessId/$outletId/$id.".($kind === 'pdf' ? 'pdf' : 'jpg');
        Storage::disk(self::DISK)->put($path, $bytes);
        try {
            DB::table('wa_media')->insert(['id' => $id, 'business_id' => $businessId, 'outlet_id' => $outletId, 'name' => mb_substr(trim($name), 0, 80) ?: 'Media',
                'kind' => $kind, 'mime' => $mime, 'path' => $path, 'bytes' => strlen($bytes), 'sha256' => hash('sha256', $bytes), 'created_at' => now(), 'updated_at' => now()]);
        } catch (\Throwable $e) {
            Storage::disk(self::DISK)->delete($path);
            throw $e;
        }
        return DB::table('wa_media')->where('id', $id)->first();
    }

    /** @return array{0:string,1:string,2:string} isi siap simpan, jenis, mime */
    public static function prepare(UploadedFile $file): array {
        $raw = (string) file_get_contents($file->getRealPath());
        $mime = (new \finfo(FILEINFO_MIME_TYPE))->buffer($raw) ?: '';
        if ($mime === 'application/pdf' && str_starts_with($raw, '%PDF-')) {
            if (strlen($raw) > (int) config('whatsapp.media.pdf_max_kb', 2048) * 1024) throw ValidationException::withMessages(['file' => 'PDF maksimal 2 MB.']);
            return [$raw, 'pdf', 'application/pdf'];
        }
        if (!in_array($mime, ['image/jpeg', 'image/png', 'image/webp'], true)) throw ValidationException::withMessages(['file' => 'Pilih foto JPG/PNG/WebP atau PDF.']);
        if (strlen($raw) > (int) config('whatsapp.media.image_max_upload_kb', 8192) * 1024) throw ValidationException::withMessages(['file' => 'Foto terlalu besar (maks. 8 MB).']);
        return [self::compress($raw), 'image', 'image/jpeg'];
    }

    /** Ubah ke JPG, sisi terpanjang ≤1600 px, turunkan kualitas sampai ±300 KB. Metadata (lokasi GPS dll.) ikut terbuang. */
    public static function compress(string $raw): string {
        if (!function_exists('imagecreatefromstring')) throw ValidationException::withMessages(['file' => 'Server belum mendukung pengolahan foto (ekstensi GD).']);
        $size = @getimagesizefromstring($raw);
        if (!$size || $size[0] < 1 || $size[1] < 1 || $size[0] * $size[1] > 40_000_000) throw ValidationException::withMessages(['file' => 'Ukuran foto tidak didukung (maks. 40 megapiksel).']);
        $src = @imagecreatefromstring($raw);
        if (!$src) throw ValidationException::withMessages(['file' => 'Foto rusak atau tidak dikenali.']);
        $w = imagesx($src); $h = imagesy($src);
        if ($w < 1 || $h < 1 || $w * $h > 40_000_000) { imagedestroy($src); throw ValidationException::withMessages(['file' => 'Ukuran foto tidak didukung.']); }
        $max = (int) config('whatsapp.media.image_max_side', 1600); $target = (int) config('whatsapp.media.image_target_kb', 300) * 1024;
        $out = '';
        foreach ([1, 0.8, 0.6] as $scale) {
            $s = min(1, $max / max($w, $h)) * $scale; $nw = max(1, (int) round($w * $s)); $nh = max(1, (int) round($h * $s));
            $dst = imagecreatetruecolor($nw, $nh);
            imagefill($dst, 0, 0, imagecolorallocate($dst, 255, 255, 255)); // PNG transparan → latar putih
            imagecopyresampled($dst, $src, 0, 0, 0, 0, $nw, $nh, $w, $h);
            foreach ([82, 72, 62, 52] as $q) {
                ob_start(); imagejpeg($dst, null, $q); $out = (string) ob_get_clean();
                if (strlen($out) <= $target) break;
            }
            imagedestroy($dst);
            if (strlen($out) <= $target) break;
        }
        imagedestroy($src);
        return $out;
    }

    public static function rename(int $businessId, string $id, string $name): object {
        $m = self::find($businessId, $id);
        DB::table('wa_media')->where('id', $m->id)->update(['name' => mb_substr(trim($name), 0, 80) ?: $m->name, 'updated_at' => now()]);
        return self::find($businessId, $id);
    }

    /** Hapus data + berkas di server; balasan cepat yang memakai media ini dilepas (teks tetap). */
    public static function delete(int $businessId, string $id): void {
        $m = self::find($businessId, $id);
        DB::transaction(function () use ($m) {
            DB::table('wa_quick_replies')->where('media_id', $m->id)->update(['media_id' => null, 'updated_at' => now()]);
            DB::table('wa_media')->where('id', $m->id)->delete();
        });
        Storage::disk(self::DISK)->delete($m->path);
    }

    /** Salin ke cabang lain milik usaha yang sama (berkas benar-benar disalin, terhapus terpisah). */
    public static function copy(int $businessId, string $id, int $toOutletId): object {
        $m = self::find($businessId, $id);
        abort_unless(DB::table('outlets')->where(['id' => $toOutletId, 'business_id' => $businessId])->whereNull('deactivated_at')->exists(), 404, 'Cabang tujuan tidak ditemukan.');
        abort_if((int) $m->outlet_id === $toOutletId, 422, 'Pilih cabang lain.');
        $bytes = Storage::disk(self::DISK)->get($m->path);
        abort_if($bytes === null, 410, 'Berkas media hilang di server. Unggah ulang.');
        return DB::transaction(function () use ($businessId, $toOutletId, $m, $bytes) {
            \App\Models\Business::whereKey($businessId)->lockForUpdate()->firstOrFail();
            self::assertRoom($businessId, $toOutletId);
            return self::insert($businessId, $toOutletId, $bytes, $m->kind, $m->mime, $m->name);
        });
    }

    /** Link sementara bertanda tangan (dipakai CHATKU untuk mengunduh, dan pratinjau di aplikasi). */
    public static function link(object $m, ?int $minutes = null): string {
        return URL::temporarySignedRoute('wa.media', now()->addMinutes($minutes ?? (int) config('whatsapp.media.link_minutes', 60)), ['id' => $m->id, 'v' => $m->version]);
    }

    /** Bentuk "media" untuk API Mitra CHATKU (§3): key berubah bila isi berubah → CHATKU tidak memakai salinan lama. */
    public static function forChatku(object $m): array {
        return ['url' => self::link($m), 'key' => 'goyana-media-'.$m->id.'-'.substr($m->sha256, 0, 12), 'filename' => $m->kind === 'pdf' ? Str::slug($m->name).'.pdf' : null];
    }

    public static function prune(): int {
        // Berkas yatim (data sudah terhapus tetapi berkas tersisa, mis. proses terputus) dibersihkan.
        $n = 0; $known = DB::table('wa_media')->pluck('path')->flip();
        foreach (Storage::disk(self::DISK)->allFiles('wa-media') as $path) {
            if (!isset($known[$path]) && Storage::disk(self::DISK)->lastModified($path) < now()->subHour()->getTimestamp()) { Storage::disk(self::DISK)->delete($path); $n++; }
        }
        return $n;
    }
}
