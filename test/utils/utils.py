import threading


def _log_stream(stream, logger):
    try:
        for line in stream:
            logger.debug(line.rstrip())
    except Exception:
        pass


def log_output(stream, logger):
    threading.Thread(target=_log_stream, args=(stream, logger), daemon=True).start()
