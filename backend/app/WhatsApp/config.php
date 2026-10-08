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
    'event_max_age_seconds' => 300,
    'template_ai_enabled' => false,
];
