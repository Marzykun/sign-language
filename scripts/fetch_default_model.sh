#!/usr/bin/env bash
# Downloads MediaPipe's stock gesture model (thumbs up, victory, ...) so the app can be
# smoke-tested before you've trained the ASL model. The trained model replaces this file.
set -euo pipefail
dest="$(dirname "$0")/../app/android/app/src/main/assets/gesture_recognizer.task"
mkdir -p "$(dirname "$dest")"
curl -fL -o "$dest" \
  https://storage.googleapis.com/mediapipe-models/gesture_recognizer/gesture_recognizer/float16/1/gesture_recognizer.task
echo "Saved $dest"
