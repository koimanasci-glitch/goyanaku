# GOYANA branding

Approved by Paduka on 6 October 2026 (latest Gas).

- `launcher.png`: supplied 162919.png, unchanged source; mipmap sizes are build resources.
- `mark.svg`: clean outline traced from the supplied launcher emblem, because the supplied wordmark and three imagegen extraction attempts contained stray opaque speckles in negative space. No wordmark text is embedded.
- `mark.png`: transparent 512px rendering of the editable SVG; header text is Flutter Text.

First-open marker: `__goyana_brand_intro_seen_v1`, separate from onboarding and the old app reset prefix. Opening animation (2200ms every open, plus a 160ms fade out once the app is ready): the G draws itself, a white bird drawn in Flutter code (no image) flies in flapping its wings and perches on it, a shine sweeps the G and the name appears letter by letter. dove.png is no longer used by the intro.

Historical screenshot tests retain their original baselines. Only the approved logo/text rectangle (x9..224, y40..87 in the 31px-inset header) is excluded when comparing historical coral headers. Scan controls, layout, body and other pixels remain locked. New symbol, native lettering, scan action and launch-marker timing have separate widget tests.
