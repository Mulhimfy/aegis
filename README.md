# Aegiss

A phone security maintainer. One screen: run a check, get a score, tap the thing
that is wrong, land on the exact system settings page that fixes it.

```
run a check ──▶ 40, At risk ──▶ "Anyone can open this phone right now"
                                        │
                                        ▼
                            why it matters, in plain words
                                        │
                                        ▼
                             [ Set a lock code ] ──▶ the real
                                                     Settings screen
                                        │
                              come back, it rescans itself
```

## What makes it worth opening

It reads the phone. Not a checklist of advice: the actual state of this device,
right now, and it says so in a sentence that names what is true.

> Missing 7 months of security patches.
> 2 apps can read everything on your screen.
> The screen never locks itself.
> This network has no password, so nothing is protected.

Most people have never seen any of that written down about their own phone.

## Rules it holds to

**Nothing leaves the device.** There is no server, no account, no analytics. An
app that reads your security posture and then uploads it would be the thing it
warns you about.

**Nothing is guessed.** When the OS refuses to disclose a signal, the check
reports as unreadable and drops out of the score rather than being assumed. The
number is only built from things that were actually measured.

**It cannot change anything.** Every fix is the user, in their own settings.
The app holds no permissions to alter the device, and says so on the first
screen before it is given anything.

**Questions the OS will not answer are asked out loud.** iOS will not tell an
app whether Stolen Device Protection is on. So the app asks, remembers the
answer for 90 days, and asks again, because a phone configured correctly last
year is not evidence about the phone today.

## How it spreads

Two shares, because two different people send two different messages.

```
[ Share my score ]              a number, a word, a link
                                pride. goes to a group chat.

[ Check someone else's phone ]  a request from someone who cares
                                concern. goes to a parent.
                                reaches people who would never
                                install a security app.
```

Both carry a referral code. The recipient's first screen shows the score they
were sent, so the app opens on a comparison rather than a pitch. A milestone
only fires when something real happened, and the prompt is capped at one a week.
The loop runs on the app being worth using, not on nagging.

## Layout

```
lib/
  core/design/     tokens, semantic system colours, themes, adaptive layer
  core/util/       phrasing shared across screens
  domain/          checks, findings, severity, scoring, the catalog
  data/probe/      DeviceProbe interface, method channel, fake
  data/prefs/      the only thing written anywhere, all local
  features/scan/   the app
  features/share/  the loop
  features/…       welcome, settings

android/app/src/main/kotlin/app/aegis/aegis/
  SecurityProbe.kt   ~25 signals, each read in isolation and guarded
  SettingsRouter.kt  a named destination to an intent chain with fallbacks

ios/Runner/
  SecurityProbe.swift  what the sandbox honestly permits, and nothing else

web/                 assetlinks + AASA for verified invite links
tool/make_icons.py   renders the mark into every icon slot both platforms want
```

## Design

Each platform gets its own app. `CupertinoApp` on Apple, `MaterialApp` on
Android, decided at the root so every screen below uses real system navigation.
No `fontFamily` is ever set, so text is SF Pro on iOS and the device's own stack
on Android. Colours come from `CupertinoColors.system*` or the Material 3 scheme,
which on Android 12+ is generated from the user's wallpaper. Radii come from each
platform's shape scale. The score dial is a thin arc and a number, with no
gradient and no glow, because dressing up a measurement is how you stop people
believing it.

## Working on it

```
flutter test                                    59 tests
flutter analyze                                 clean
flutter build apk --release --split-per-abi
python tool/make_icons.py                       regenerate icons

AEGIS_DUMP_CARDS=<dir> flutter test test/share_card_test.dart
                                                write the share cards out as PNGs
```

Release signing reads `android/key.properties`; see `key.properties.example`.
Without it a release build falls back to the debug key, which is fine locally
and not fine on Play.

## Adding a check

One entry in `lib/domain/catalog.dart`: the `Check` describing it and the rule
that judges it. If it needs a new signal, add it to `DeviceSignals` and read it
in the native probe inside a `guard`, returning null when the platform will not
say. If it needs a new settings destination, add the target to `SettingsTarget`
and give `SettingsRouter` an intent chain for it.

Tests will hold you to it: every check must explain itself in more than a
sentence, every attested check must ask an answerable question, and no check may
appear on a platform it cannot be evaluated on.
