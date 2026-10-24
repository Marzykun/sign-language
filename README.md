# Sign Translator

An Android app that reads American Sign Language (ASL) fingerspelling from the camera and types it out.
Hold a letter steady for about a second to type it, and tap **Speak** to read the text aloud.

Built with Flutter. Hand tracking and letter recognition run on the phone using
[MediaPipe's Gesture Recognizer](https://ai.google.dev/edge/mediapipe/solutions/vision/gesture_recognizer),
fine-tuned on a public ASL alphabet dataset. Nothing leaves the device.

## How it works

```
CameraX frame ─▶ MediaPipe Gesture Recognizer ─▶ label + score + 21 hand points
   (Kotlin)          (gesture_recognizer.task)          │  EventChannel
                                                         ▼
                                        Flutter: LetterComposer (hold-to-type) ─▶ transcript, TTS
```

| Path | What it is |
|---|---|
| `app/android/.../SignCamera.kt` | Camera preview (platform view) and recognizer; sends results to Dart |
| `app/lib/letter_composer.dart` | Turns per-frame predictions into text (hold, repeat, flicker tolerance) |
| `app/lib/translator_screen.dart` | The UI |
| `ml/train_asl_alphabet.ipynb` | Colab notebook that produces the model |

## Setup

You need Flutter, Android Studio (for the Android SDK) and an Android phone (API 24+) with USB debugging on.
The emulator camera isn't good enough to test signing.

### 1. Get the model

The app loads `app/android/app/src/main/assets/gesture_recognizer.task`.

**Option A: train the ASL model (about 20 minutes, mostly waiting)**
1. Open `ml/train_asl_alphabet.ipynb` in [Google Colab](https://colab.research.google.com/) (File → Upload notebook).
2. Click *Runtime → Run all*.
3. When it finishes it downloads `gesture_recognizer.task`. Copy that file to the assets path above.

**Option B: quick smoke test with MediaPipe's stock model**
```bash
./scripts/fetch_default_model.sh
```
This model only knows gestures like 👍 and ✌️, so it won't type anything, but the overlay and labels will show that the camera and recognizer work.

### 2. Run

```bash
cd app
flutter pub get
flutter run
```

## Using it

- Sign a letter with one hand inside the frame and hold it until the ring fills.
- Keep holding to repeat it (for double letters like "LL").
- The `space` and `del` signs from the dataset work, and so do the buttons under the text.
- Use good, even light and a plain background.

## Limitations

- Only the static alphabet. J and Z involve motion, so they're unreliable.
- Look-alike letters (M/N/S/T/A, U/V) get confused sometimes.
- If `pip install mediapipe-model-maker` fails in Colab (it pins an older TensorFlow), switch the runtime
  to an older Python version if Colab offers one, or run the notebook locally with Python 3.10/3.11.
