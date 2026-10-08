<?php
namespace App\WhatsApp;
use Illuminate\Support\Facades\DB;
/** Conservative privacy boundary: model sees approved topic identifiers and counts only. */
final class TopicStats {
    public const TOPICS=['layanan_boneka','layanan_sepatu','layanan_karpet','jadwal_jemput','jam_operasional','harga_layanan','unclassified'];
    public static function record(string $text): void {
        $t=mb_strtolower($text); $topic='unclassified';
        foreach(['boneka'=>'layanan_boneka','sepatu'=>'layanan_sepatu','karpet'=>'layanan_karpet','jemput'=>'jadwal_jemput','buka'=>'jam_operasional','harga'=>'harga_layanan']as$word=>$candidate){
            if(preg_match('/(?<!\pL)'.$word.'(?!\pL)/u',$t)){$topic=$candidate;break;}
        }
        $key=['day'=>now()->toDateString(),'topic'=>$topic];
        DB::table('wa_unknown_topics')->insertOrIgnore($key+['count'=>0]);
        DB::table('wa_unknown_topics')->where($key)->increment('count');
    }
}
