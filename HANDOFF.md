# Aegis — state of play

```
STATUS   analyze: clean  |  tests: 59 passing  |  release apk: 17.7 MB per-abi
REPO     C:\Users\dell\aegis      32 dart files, ~5.9k lines, 8 packages
```

```
flutter test
flutter build apk --release --split-per-abi
adb install -r -t build/app/outputs/flutter-apk/app-x86_64-release.apk
python tool/make_icons.py                 regenerate every icon
AEGIS_DUMP_CARDS=<dir> flutter test test/share_card_test.dart
```

## The app

```
one screen ─▶ check ─▶ score ─▶ tap a finding ─▶ why it matters
                                                      │
                                          one tap into the exact
                                          system settings screen
                                                      │
                                        come back, it re-checks itself
```

Two ways to pass it on, both from the bottom of the list:
`Share my score` (a card and a link) and `Check someone else's phone`.
Both carry a referral code. The new user's first screen shows the score
they were sent.

## Cut for minimalism (this pass)

```
monthly reminders     2 packages, 3 permissions incl. SCHEDULE_EXACT_ALARM,
                      and the source of the worst bug of the build
history + sparkline   ~250 lines, rarely opened
"sign it" name field  an extra step inside the share flow. The chat the
                      card lands in already says who sent it.
VPN advisory check    weight 0, pure noise
Severity.advisory     nothing used it once the VPN check went
settings switches     there are none left; every switch is a decision the
                      app failed to make
copy                  every section footer and every explanation rewritten
                      shorter. The "why" stays: it is the product.
```

Result: 34 files to 32, ~6.9k lines to ~5.9k, 10 packages to 8,
5 Android permissions to 2, APK 19.2 MB to 17.7 MB.

## Verified end to end on device (before the cuts)

```
[x] invite link opens the app on the sender's score
[x] check reads real emulator state -> 40, At risk
[x] findings true: no screen lock, USB debugging, patch 7 months old,
    open wi-fi, never locks, backup off
[x] detail -> [Set a lock code] -> Android Security & privacy, with
    "Set screen lock" front and centre
[x] Share my score -> card preview -> system sheet, image attached,
    link carrying the referral code
[x] dark mode, Material You colour from the wallpaper
[ ] the leaner build has not been eyeballed on device yet: analyze is
    clean and all 59 tests pass, but the emulator would not come back up
[ ] iOS: written and wired into project.pbxproj, never compiled
```

## Bugs found by actually running it

```
1  routes were built above AppScope -> every pushed page crashed
2  "Stays unlocked for 35791 minutes": Android stores "never" near int max
3  critical clamp flattened ordering; now scales, so 2 criticals < 1
4  canRequestPackageInstalls() only reports this app -> that check was
   silently wrong; it is attested now
5  "Link copied" snackbar drew behind the modal sheet
6  overflow in the finding-detail header row
7  the share card was only reachable from a milestone
8  the notification icon was stripped by the resource shrinker, the plugin
   threw, and because main() awaited it the app hung on its own splash
9  a reminder failure could turn a completed scan into a failed one
10 the score dial retargeted its animation outside setState. Passed under
   pumpAndSettle, showed 0 forever on a real device. Now declarative.
11 history sparkline filled its area: a flat run looked like a grey slab
12 four scans in one afternoon all read "12 Aug 2026"
```

8, 9 and 10 have regression tests. 11 and 12 went out with history.

## Left

```
1  run the leaner build on a device
2  iOS build. Probe, icons, launch image, URL scheme, pbxproj: all done.
3  assetlinks.json needs the Play app-signing SHA-256; the AASA needs the
   Team ID. Until then aegis:// carries every invite, so the loop works.
4  android/key.properties for a real upload key
5  the aegis.app landing page: /s/<code> and /c/<code> should bounce to
   the store and echo the ?v= score
6  not a git repo yet
```

## Design rules being held

```
no fontFamily is ever set          SF Pro on iOS, the device stack on Android
no invented colours                CupertinoColors.system* / M3 from wallpaper
no invented radii                  each platform's own shape scale
CupertinoApp on Apple, MaterialApp on Android, decided at the root
nothing leaves the phone, ever
nothing is guessed: an unreadable signal drops out of the score
```
