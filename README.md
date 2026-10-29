# Sign Translator

An Android app that reads American Sign Language (ASL) fingerspelling from the camera and types it out.
Hold a letter steady for about a second to type it, and tap **Speak** to read the text aloud.

It works fully offline with nothing to train. Google's pretrained
[MediaPipe Hand Landmarker](https://ai.google.dev/edge/mediapipe/solutions/vision/hand_landmarker)
(bundled in the app) finds 21 points on your hand, and hand-written geometry rules turn those points into letters.

## Download

Every push builds a release APK with GitHub Actions:

- **Latest build:** open the [Actions tab](../../actions/workflows/build-apk.yml), pick the newest green run,
  and download `sign-translator-apk` under *Artifacts* (it's a zip with the APK inside).
- **Releases:** the [Releases page](../../releases) has the APK for each version. To publish one, push a tag
  such as `v1.1.0`, or run the *Build release APK* workflow by hand and enter the tag.

To install, copy the APK to your phone, open it, and allow installs from that source when Android asks.
Android 7.0 (API 24) or newer is required.

## How it works

```
CameraX frame ─▶ MediaPipe Hand Landmarker ─▶ 21 hand points ─▶ FingerspellingRules ─▶ LetterComposer ─▶ text, speech
   (Kotlin)        (hand_landmarker.task)       EventChannel         (Dart)              (hold-to-type)
```

The rules work out, for each finger, whether it's straight, bent or curled. They also check where the
thumb sits and which way the hand points. For example:

- **L:** index finger straight, thumb out, the rest curled.
- **V:** index and middle fingers straight and spread apart.
- **Y:** thumb and pinky out, the rest curled.

| Path | What it is |
|---|---|
| `app/android/.../SignCamera.kt` | Camera preview (platform view) and hand tracking; sends points to Dart |
| `app/lib/fingerspelling_rules.dart` | Hand points → letter |
| `app/lib/letter_composer.dart` | Per-frame letters → typed text (hold, repeat, flicker tolerance) |
| `app/lib/translator_screen.dart` | The UI |

## Supported letters

| Recognised | Not supported |
|---|---|
| A B C D E F G H I K L O P Q R S U V W X Y (21 letters) | J, Z (they involve motion), M N T (the thumb is hidden under the fingers) |

G and H are signed with the hand sideways; P and Q with it pointing down.

## Using it

- Keep one hand inside the frame, palm facing the camera, in good light.
- Hold a letter until the ring fills to type it. Keep holding to repeat it (for double letters like "LL").
- Use the buttons under the text for space, delete and clear.

## Building it yourself

You need Flutter 3.47+ and the Android SDK (installed with Android Studio).

```bash
cd app
flutter pub get
flutter test             # unit tests for the rules and the composer
flutter run              # on a phone with USB debugging enabled
flutter build apk --release
```

The release APK is signed with the debug key, which is fine for installing it yourself but not for the
Play Store. Builds from different machines (including CI) use different debug keys, so to install a newer
build you may need to uninstall the old one first.

## Limitations

- Rules are sensitive to hand angle. Face your palm to the camera and keep your fingers clearly visible.
- Look-alike letters (A/S/E, U/V/R/K) can get confused.
