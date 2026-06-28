import av


def decode_mpeg_ts_audio(input_file_path):
    # Open the MPEG-TS container
    container = av.open(input_file_path)

    # Locate the best available audio stream
    try:
        audio_stream = container.streams.audio[0]
        print(f"Codec: {audio_stream.codec_context.name}")
        print(f"Sample Rate: {audio_stream.codec_context.sample_rate} Hz")
        print(f"Channels: {audio_stream.codec_context.channels}")
    except IndexError:
        print("No audio stream found in this file.")
        return

    for packet in container.demux(audio_stream):
        print("packet", packet)
        yield from packet.decode()


def main():
    for frame in decode_mpeg_ts_audio("input.ts"):
        print(frame)


main()
