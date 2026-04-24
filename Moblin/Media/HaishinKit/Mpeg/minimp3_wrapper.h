#pragma once
#include <stdint.h>
#include "minimp3.h"

typedef struct {
    int frame_bytes;
    int channels;
    int hz;
    int layer;
    int bitrate_kbps;
} MiniMp3FrameInfo;

// Decode one MPEG audio frame. Returns number of PCM samples written (per channel).
// pcm must point to a buffer of at least MINIMP3_MAX_SAMPLES_PER_FRAME * sizeof(int16_t).
int minimp3_decode_frame(const uint8_t *data, int data_size,
                         int16_t *pcm, MiniMp3FrameInfo *info);
