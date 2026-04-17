#!/bin/bash
# SessionEnd hook: remove /tmp/video-analyze-* scratch dirs created by video-detect.sh.
# MUST NOT run on Stop — Stop fires between turns, which would wipe frames before
# Claude finishes reading them in multi-turn video conversations.
for dir in /tmp/video-analyze-*; do
  [ -d "$dir" ] && rm -rf "$dir"
done
exit 0
