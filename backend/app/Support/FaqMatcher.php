<?php
namespace App\Support;
use Illuminate\Support\Facades\DB;
/** Program-first CS: pick the FAQ whose keywords best match the question; null = no confident match (goes to a human/AI). */
class FaqMatcher {
    public static function normalize(string $text): string {
        $t = mb_strtolower($text);
        $t = preg_replace('/[^\p{L}\p{N}\s]+/u', ' ', $t);
        return ' '.preg_replace('/\s+/u', ' ', trim($t)).' ';
    }
    public static function match(string $text): ?object {
        $hay = self::normalize($text); $best = null; $bestScore = 0;
        foreach (DB::table('faqs')->where('active', true)->orderBy('id')->get() as $faq) {
            $score = 0;
            foreach (explode(',', $faq->keywords) as $kw) {
                $kw = trim(self::normalize($kw));
                // Whole words/phrases only, longer phrases count more ("tidak bisa login" beats "login").
                if ($kw !== '' && str_contains($hay, ' '.$kw.' ')) $score += substr_count($kw, ' ') + 1;
            }
            if ($score > $bestScore) { $best = $faq; $bestScore = $score; }
        }
        return $best;
    }
}
