# video-analyze

Claude Code plugin that auto-analyzes videos mentioned in your prompts. Share a screen recording or video URL — Claude extracts keyframes, transcribes audio with Whisper, and sees/hears the content as if you'd described it.

## What it does

When you submit a prompt containing a video path or URL, a `UserPromptSubmit` hook:

1. Detects the reference (quoted paths, backslash-escaped, tilde paths, plain paths with spaces, HTTP/HTTPS URLs, macOS Screen Recording filenames with U+202F narrow no-break space)
2. Extracts keyframes with `ffmpeg` (default: 1 frame every 2 seconds)
3. Transcribes audio with `whisper-cpp` (if speech is present)
4. Injects frame paths + transcript into Claude's context so Claude can `Read` each frame image and respond naturally

Temp files land in `/tmp/video-analyze-*` and are cleaned up on `SessionEnd`.

## Install

```
/plugin marketplace add EcomGraduates/video-analyze
/plugin install video-analyze@ecomgraduates
```

Restart Claude Code. The first video you share triggers a one-time install of `ffmpeg`, `whisper-cpp`, and the `ggml-small.bin` Whisper model (~488 MB) via Homebrew.

## Requirements

- macOS (Apple Silicon or Intel)
- [Homebrew](https://brew.sh) — used to install `ffmpeg` and `whisper-cpp` on first run
- Python 3 (ships with macOS)

## Usage

Just mention a video in a prompt:

```
check out this bug /Users/me/Desktop/Screen Recording 2026-04-17 at 1.26.27 PM.mov
```

or

```
can you analyze https://example.com/demo.mp4
```

Claude will see the frames and hear the audio, then respond to whatever you actually asked.

## Supported formats

mp4, mov, avi, mkv, webm, m4v, flv, wmv, mpg, mpeg, ts, mts, 3gp

## Files

- `hooks/video-detect.sh` — UserPromptSubmit hook (Python)
- `hooks/video-cleanup.sh` — SessionEnd hook (clears `/tmp` scratch)
- `bin/video-analyze` — ffmpeg + whisper-cpp runner

## License

MIT
