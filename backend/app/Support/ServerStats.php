<?php
namespace App\Support;

use Illuminate\Support\Facades\DB;

/**
 * Monitor VPS untuk divisi teknis: RAM, beban CPU, disk, lama menyala, ukuran database.
 * Dibaca langsung dari server (Linux /proc). Di sistem lain angka yang tidak tersedia dikembalikan null.
 */
final class ServerStats {
    public static function now(): array {
        $mem = self::memory(); $disk = self::disk(); $load = function_exists('sys_getloadavg') ? (sys_getloadavg() ?: null) : null;
        $cores = self::cores();
        return [
            'ram_total' => $mem['total'], 'ram_used' => $mem['used'], 'ram_percent' => self::percent($mem['used'], $mem['total']),
            'swap_total' => $mem['swap_total'], 'swap_used' => $mem['swap_used'],
            'load1' => $load[0] ?? null, 'load5' => $load[1] ?? null, 'load15' => $load[2] ?? null, 'cpu_cores' => $cores,
            // Beban 1 menit dibanding jumlah inti: 100% berarti semua inti sibuk.
            'cpu_percent' => isset($load[0]) && $cores ? (int) round(min(999, $load[0] / $cores * 100)) : null,
            'disk_total' => $disk['total'], 'disk_used' => $disk['used'], 'disk_percent' => self::percent($disk['used'], $disk['total']),
            'uptime_seconds' => self::uptime(), 'database_bytes' => self::databaseBytes(),
        ];
    }

    /** kuning ≥ 80%, merah ≥ 92% */
    public static function state(?int $percent): string {
        return $percent === null ? 'warn' : ($percent >= 92 ? 'fail' : ($percent >= 80 ? 'warn' : 'ok'));
    }

    /** Dicatat penjadwal tiap 5 menit; disimpan 8 hari untuk grafik. */
    public static function record(): void {
        $s = self::now();
        if ($s['ram_total'] === null || $s['disk_total'] === null) return;
        DB::table('server_metrics')->insert(['ram_used' => $s['ram_used'], 'ram_total' => $s['ram_total'], 'load1' => (float) ($s['load1'] ?? 0),
            'cpu_cores' => (int) ($s['cpu_cores'] ?? 1), 'disk_used' => $s['disk_used'], 'disk_total' => $s['disk_total'], 'created_at' => now()]);
        DB::table('server_metrics')->where('created_at', '<', now()->subDays(8))->delete();
    }

    /** Riwayat 24 jam untuk grafik: [{at, ram, cpu}] dalam persen. */
    public static function history(int $hours = 24): array {
        return DB::table('server_metrics')->where('created_at', '>=', now()->subHours($hours))->orderBy('id')->get()->map(fn ($r) => [
            'at' => (string) $r->created_at, 'ram' => self::percent((int) $r->ram_used, (int) $r->ram_total) ?? 0,
            'cpu' => (int) round(min(100, $r->cpu_cores ? $r->load1 / $r->cpu_cores * 100 : 0)),
        ])->all();
    }

    public static function bytes(?int $n): string {
        if ($n === null) return '—';
        return $n >= 1073741824 ? number_format($n / 1073741824, 1, ',', '.').' GB' : number_format($n / 1048576, 0, ',', '.').' MB';
    }

    public static function duration(?int $seconds): string {
        if ($seconds === null) return '—';
        $d = intdiv($seconds, 86400); $h = intdiv($seconds % 86400, 3600); $m = intdiv($seconds % 3600, 60);
        return $d > 0 ? $d.' hari '.$h.' jam' : ($h > 0 ? $h.' jam '.$m.' menit' : $m.' menit');
    }

    private static function percent(?int $used, ?int $total): ?int {
        return $used === null || !$total ? null : (int) round($used / $total * 100);
    }

    private static function memory(): array {
        $out = ['total' => null, 'used' => null, 'swap_total' => null, 'swap_used' => null];
        $raw = @file_get_contents('/proc/meminfo');
        if (!is_string($raw)) return $out;
        $kb = [];
        foreach (explode("\n", $raw) as $line) if (preg_match('/^(\w+):\s+(\d+)/', $line, $m)) $kb[$m[1]] = (int) $m[2] * 1024;
        if (empty($kb['MemTotal'])) return $out;
        $available = $kb['MemAvailable'] ?? (($kb['MemFree'] ?? 0) + ($kb['Buffers'] ?? 0) + ($kb['Cached'] ?? 0));
        return ['total' => $kb['MemTotal'], 'used' => max(0, $kb['MemTotal'] - $available),
            'swap_total' => $kb['SwapTotal'] ?? 0, 'swap_used' => max(0, ($kb['SwapTotal'] ?? 0) - ($kb['SwapFree'] ?? 0))];
    }

    private static function disk(): array {
        $total = @disk_total_space(base_path()); $free = @disk_free_space(base_path());
        return $total && $free !== false ? ['total' => (int) $total, 'used' => (int) ($total - $free)] : ['total' => null, 'used' => null];
    }

    private static function cores(): ?int {
        $raw = @file_get_contents('/proc/cpuinfo');
        $n = is_string($raw) ? preg_match_all('/^processor\s*:/m', $raw) : 0;
        return $n > 0 ? $n : null;
    }

    private static function uptime(): ?int {
        $raw = @file_get_contents('/proc/uptime');
        return is_string($raw) && is_numeric(strtok($raw, ' ')) ? (int) (float) strtok($raw, ' ') : null;
    }

    private static function databaseBytes(): ?int {
        try {
            $connection = DB::connection(); $driver = $connection->getDriverName();
            if ($driver === 'sqlite') { $path = $connection->getDatabaseName(); return is_file($path) ? (int) filesize($path) : null; }
            if ($driver === 'mysql' || $driver === 'mariadb') {
                $row = DB::selectOne('select sum(data_length + index_length) as n from information_schema.tables where table_schema = ?', [$connection->getDatabaseName()]);
                return $row && $row->n !== null ? (int) $row->n : null;
            }
            if ($driver === 'pgsql') return (int) DB::selectOne('select pg_database_size(current_database()) as n')->n;
        } catch (\Throwable) {}
        return null;
    }
}
