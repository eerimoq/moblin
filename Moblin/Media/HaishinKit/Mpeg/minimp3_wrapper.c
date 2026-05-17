#define MINIMP3_IMPLEMENTATION
#include "minimp3_wrapper.h"

static mp3dec_t g_mp3dec;
static int g_mp3dec_initialized = 0;

int minimp3_decode_frame(const uint8_t *data, int data_size,
                         int16_t *pcm, MiniMp3FrameInfo *info)
{
    if (!g_mp3dec_initialized) {
        mp3dec_init(&g_mp3dec);
        g_mp3dec_initialized = 1;
    }
    mp3dec_frame_info_t mp3info;
    int samples = mp3dec_decode_frame(&g_mp3dec, data, data_size, pcm, &mp3info);
    if (info) {
        info->frame_bytes    = mp3info.frame_bytes;
        info->channels       = mp3info.channels;
        info->hz             = mp3info.hz;
        info->layer          = mp3info.layer;
        info->bitrate_kbps   = mp3info.bitrate_kbps;
    }
    return samples;
}
