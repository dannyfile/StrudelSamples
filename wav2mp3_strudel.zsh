#!/usr/bin/env zsh
# wav2mp3_strudel.zsh
# Требуется: ffmpeg (включая ffprobe):  brew install ffmpeg

set -euo pipefail

# Порог (сек): <= THRESH → VBR,  > THRESH → CBR
# 3.0с ≈ one-shot/короткие семплы; можно поменять, установив переменную окружения THRESH
: ${THRESH:=3.0}

# Корневая папка (по умолчанию — текущая)
ROOT="${1:-.}"

# Проверка ffmpeg/ffprobe
command -v ffmpeg  >/dev/null 2>&1 || { echo "ffmpeg не найден. Установи: brew install ffmpeg"; exit 1; }
command -v ffprobe >/dev/null 2>&1 || { echo "ffprobe не найден. Установи: brew install ffmpeg"; exit 1; }

typeset -F THRESH

echo "Старт: корень='$ROOT', порог=${THRESH}s (<= VBR V0, > CBR 320k), 48 kHz"

# Находим WAV (и WAV в верхнем регистре) рекурсивно
find "$ROOT" -type f \( -iname '*.wav' \) -print0 | while IFS= read -r -d '' f; do
  base="${f%.*}"
  out="${base}.mp3"

  # Если уже есть mp3 — пропускаем
  if [[ -f "$out" ]]; then
    echo "⏭  Уже есть: $out (пропуск)"
    continue
  fi

  # Длительность (сек, float)
  dur="$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$f" || echo 0)"
  float DUR=${dur:-0}

  # Выбор режима кодирования
  if (( DUR > THRESH )); then
    # Длинные лупы → CBR 320 kbps
    echo "🎛  CBR 320k:  '$f'  (длительность ${DUR}s)"
    ffmpeg -v error -y -i "$f" -vn -ar 48000 -ac 2 -codec:a libmp3lame -b:a 320k -map_metadata 0 "$out"
  else
    # Короткие one-shots → VBR V0
    echo "✨  VBR V0:    '$f'  (длительность ${DUR}s)"
    ffmpeg -v error -y -i "$f" -vn -ar 48000 -ac 2 -codec:a libmp3lame -qscale:a 0 -map_metadata 0 "$out"
  fi
done

echo "✅ Готово."
