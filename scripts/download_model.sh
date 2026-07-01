#!/bin/bash
# Downloads the on-device model into Resources/Models/ so XcodeGen bundles it
# into the app. Run this once before `xcodegen generate` / `xcodebuild`.
#
# Default: Qwen2.5-0.5B-Instruct, Q4_K_M quantization (~400MB) — same model
# family as the Android app's default ("qwen2.5:0.5b" via Ollama), just
# packaged as a GGUF file for on-device llama.cpp instead of a server call.
#
# Want a smarter (but bigger/slower) assistant? Swap MODEL_URL below for one
# of these and update LocalLLMService.modelFileName to match:
#   - Qwen2.5-1.5B-Instruct-Q4_K_M.gguf  (~1.0GB)  — noticeably smarter
#   - Llama-3.2-3B-Instruct-Q4_K_M.gguf  (~2.0GB)  — best quality, needs a
#     newer iPhone (A15/6GB RAM or better recommended)

set -euo pipefail

MODEL_URL="${MODEL_URL:-https://huggingface.co/bartowski/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/Qwen2.5-0.5B-Instruct-Q4_K_M.gguf}"
DEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/Resources/Models"
DEST_FILE="$DEST_DIR/qwen2.5-0.5b-instruct-q4_k_m.gguf"

mkdir -p "$DEST_DIR"

if [ -f "$DEST_FILE" ]; then
  echo "Model already present at $DEST_FILE — skipping download."
  exit 0
fi

echo "Downloading on-device model from:"
echo "  $MODEL_URL"
echo "to:"
echo "  $DEST_FILE"

curl -L --fail --progress-bar "$MODEL_URL" -o "$DEST_FILE"

echo "Done. ($(du -h "$DEST_FILE" | cut -f1))"
