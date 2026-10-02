<?php

namespace Tests;

use App\Models\User;
use Illuminate\Foundation\Testing\TestCase as BaseTestCase;

abstract class TestCase extends BaseTestCase
{
    /** Platform admin who has already passed OTP in this session. */
    protected function actingAsAdmin(User $admin): static
    {
        if (!$admin->mfa_confirmed_at) {
            $admin->mfa_secret = \App\Support\Totp::secret();
            $admin->mfa_confirmed_at = now();
            $admin->save();
        }
        return $this->actingAs($admin)->withSession(['mfa_passed_for' => $admin->id]);
    }
}
