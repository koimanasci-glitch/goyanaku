<?php
return [
    // API perangkat dan webhook hanya terbuka bila GOYANA_WHATSAPP_ENABLED=true di .env server.
    // Tanpa adapter Chatku resmi, pemasangan dan pengiriman tetap menjawab 503 (tidak ada QR/status palsu).
    'enabled' => (bool) env('GOYANA_WHATSAPP_ENABLED', false),
    'connection_packages' => ['Silver', 'Gold', 'Platinum'],
    'base_slots' => 1,
    // Keputusan Paduka 8 Oktober 2026: Balas Status WhatsApp mulai dari Silver (Basic tidak).
    'status_packages' => ['Silver', 'Gold', 'Platinum'],
    'services_packages' => ['Gold', 'Platinum'],
    // Keputusan Paduka 10 Oktober 2026 (sama dengan gerbang aplikasi, access.dart): Balasan Cepat Silver+, Chatbot AI & pesan otomatis Gold+, Blast Platinum.
    'quick_packages' => ['Silver', 'Gold', 'Platinum'],
    'ai_packages' => ['Gold', 'Platinum'],
    'messages_packages' => ['Gold', 'Platinum'],
    'blast_packages' => ['Platinum'],
    'event_max_age_seconds' => 300,
    'template_ai_enabled' => false,
    // Antrean WA: "database" + layanan worker Docker (pasang-goyana.sh) supaya webhook dijawab cepat dan AI tidak menahan permintaan.
    // Kosong = koneksi antrean bawaan (QUEUE_CONNECTION).
    'queue_connection' => env('GOYANA_WA_QUEUE_CONNECTION'),

    // Adapter resmi ke API Mitra CHATKU (KONTRAK-API-MITRA.md). Kunci hanya di .env server, tidak pernah di aplikasi HP.
    'chatku' => [
        'base_url' => rtrim((string) env('CHATKU_BASE_URL', 'https://chatku.id'), '/').'/api/partner/v1',
        'api_key' => env('CHATKU_API_KEY'),
        'webhook_secret' => env('CHATKU_WEBHOOK_SECRET'),
        'timeout' => (int) env('CHATKU_TIMEOUT', 20),
        // Sub-akun CHATKU per usaha laundry: "biz-<id>"; nomor marketing pusat GOYANA di sub-akun sendiri.
        'tenant_prefix' => 'biz-',
        'marketing_tenant' => 'goyana-pusat',
    ],

    // Media balasan (keputusan Paduka 10 Okt): maks. 10 per cabang, foto (dikompres ±300 KB) atau PDF maks. 2 MB.
    'media' => [
        'per_outlet' => 10,
        'image_max_upload_kb' => 8192,
        'image_target_kb' => 300,
        'image_max_side' => 1600,
        'pdf_max_kb' => 2048,
        'link_minutes' => 60,
    ],
    // Pemilik membalas langsung dari HP → bot diam untuk kontak itu selama N menit (bisa diubah per cabang).
    'takeover_minutes' => 30,
    // Riwayat percakapan singkat untuk AI (terenkripsi, dihapus otomatis).
    'chat_log_hours' => 24,
];
