<?php

/*
 | GOYANA business rules that the server enforces.
 | Source: GOYANA-SISTEM-PUSAT.md §5 (katalog) and GOYANA-ROADMAP.md §6/§37.
 */
return [

    // Trial: Basic for 2 months, then READ-ONLY until a paid package is active
    // (keputusan pengguna 2 Oktober 2026 — tidak ada paket gratis yang tetap bisa dipakai).
    'trial' => ['package' => 'Basic', 'months' => 2],

    // branches = cabang di luar 1 outlet pusat. Basic: 1 pusat + 1 cabang (ditegaskan pengguna 2 Oktober 2026).
    'packages' => [
        'Basic' => ['price' => 30000, 'branches' => 1, 'rank' => 1],
        'Silver' => ['price' => 65000, 'branches' => 2, 'rank' => 2],
        'Gold' => ['price' => 100000, 'branches' => 3, 'rank' => 3],
        'Platinum' => ['price' => 350000, 'branches' => 5, 'rank' => 4],
    ],

    // Maksimal perangkat kasir per outlet (termasuk pusat).
    'cashier_devices_per_outlet' => 2,

    'roles' => [
        'owner' => ['label' => 'Owner', 'permissions' => ['*']],
        'kasir' => ['label' => 'Kasir', 'permissions' => [
            'orders.create', 'orders.update', 'orders.status', 'payments.receive',
            'discounts.limited', 'customers.manage', 'courier.assign', 'cash.manage',
        ]],
        'produksi' => ['label' => 'Produksi', 'permissions' => ['orders.status', 'stock.use']],
        'kurir' => ['label' => 'Kurir', 'permissions' => ['courier.tasks']],
        'manager' => ['label' => 'Admin Outlet', 'permissions' => [
            'orders.create', 'orders.update', 'orders.status', 'orders.cancel',
            'payments.receive', 'payments.refund', 'discounts.any', 'prices.edit',
            'customers.manage', 'stock.manage', 'courier.assign', 'cash.manage', 'reports.view',
        ]],
    ],

    // Admin pusat wajib OTP (aplikasi authenticator). Matikan hanya untuk pengembangan lokal.
    'admin_mfa' => env('GOYANA_ADMIN_MFA', true),

    // Wajibkan verifikasi email owner. Aktifkan setelah SMTP/email pengirim produksi siap.
    'require_email_verification' => env('GOYANA_REQUIRE_EMAIL_VERIFICATION', false),

    /*
     | Sync collections from the Android app. write = any of these permissions may change it,
     | read = any of these may download it ('*' = every role of the business).
     | scope outlet = record belongs to one outlet (staff only see their outlet); business = shared.
     | transactional = writing it uses a cashier device slot (max 2 per outlet).
     */
    'sync' => [
        'max_changes' => 200,
        'max_record_bytes' => 400000,
        'collections' => [
            'orders' => ['scope' => 'outlet', 'transactional' => true, 'read' => ['*'],
                'write' => ['orders.create', 'orders.update', 'orders.status', 'payments.receive', 'courier.tasks']],
            'kas' => ['scope' => 'outlet', 'transactional' => true, 'read' => ['cash.manage'], 'write' => ['cash.manage']],
            'deposits' => ['scope' => 'business', 'transactional' => true, 'read' => ['payments.receive'], 'write' => ['payments.receive']],
            'customers' => ['scope' => 'business', 'read' => ['*'], 'write' => ['customers.manage', 'orders.create']],
            'services' => ['scope' => 'business', 'read' => ['*'], 'write' => ['prices.edit']],
            'settings' => ['scope' => 'business', 'read' => ['*'], 'write' => ['prices.edit']],
            'outlet_profiles' => ['scope' => 'business', 'read' => ['*'], 'write' => ['owner']],
            'couriers' => ['scope' => 'business', 'read' => ['courier.assign', 'courier.tasks'], 'write' => ['courier.assign']],
            'stock_items' => ['scope' => 'business', 'read' => ['stock.manage', 'stock.use'], 'write' => ['stock.manage']],
            'stock_ledger' => ['scope' => 'business', 'read' => ['stock.manage', 'stock.use'], 'write' => ['stock.manage', 'stock.use']],
            'stock_suppliers' => ['scope' => 'business', 'read' => ['stock.manage'], 'write' => ['stock.manage']],
            'stock_purchases' => ['scope' => 'business', 'read' => ['stock.manage'], 'write' => ['stock.manage']],
            'stock_recipes' => ['scope' => 'business', 'read' => ['stock.manage', 'stock.use'], 'write' => ['stock.manage']],
        ],
    ],
];
