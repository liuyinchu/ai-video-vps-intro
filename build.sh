#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build output
binary="build/make-video"
voice_binary="build/edge-voice"
compile_voice() {
  if [[ ! -f sources/NeuralVoice.swift || ! -f sources/EdgeToken.swift ]]; then
    echo "Missing neural voice client sources: sources/NeuralVoice.swift and sources/EdgeToken.swift" >&2
    return 1
  fi
  if [[ ! -x "$voice_binary" || sources/NeuralVoice.swift -nt "$voice_binary" || sources/EdgeToken.swift -nt "$voice_binary" ]]; then
    echo "Compiling the neural voice client…"
    local temporary="build/.edge-voice-$$"
    if /usr/bin/xcrun swiftc -O -parse-as-library sources/NeuralVoice.swift sources/EdgeToken.swift -o "$temporary"; then
      mv "$temporary" "$voice_binary"
    else
      rm -f "$temporary"
      return 1
    fi
  fi
}
if [[ "${1:-build}" == "build-voice" ]]; then
  compile_voice
  echo "Ready: $voice_binary"
  exit 0
fi
if [[ ! -x "$binary" || sources/main.swift -nt "$binary" || sources/Scenes.swift -nt "$binary" ]]; then
  echo "Compiling the native video maker…"
  temporary="build/.make-video-$$"
  if /usr/bin/xcrun swiftc -O sources/main.swift sources/Scenes.swift -o "$temporary" \
    -framework AppKit -framework AVFoundation -framework CoreGraphics -framework CoreVideo -framework ImageIO; then
    mv "$temporary" "$binary"
  else
    rm -f "$temporary"
    exit 1
  fi
fi
if [[ $# -eq 0 || "$1" == "build" ]]; then
  echo "Ready: $binary"
  exit 0
fi
if [[ "$1" == "synthesize" ]]; then
  compile_voice
fi
exec "$binary" "$@"
