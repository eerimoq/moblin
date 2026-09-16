def text_segments(text: str) -> list[dict]:
    return [{"id": index, "text": f"{word} "} for index, word in enumerate(text.split())]


def big_gif_segments(url: str) -> list[dict]:
    return [{"id": 0, "bigGifUrl": {"moving": url}}]


def highlight(kind: str, bar_color: tuple[int, int, int], image: str, title: str) -> dict:
    red, green, blue = bar_color
    return {
        "kind": {kind: {}},
        "barColor": {"red": red, "green": green, "blue": blue},
        "image": image,
        "titleSegments": text_segments(title),
    }


def first_message_highlight() -> dict:
    return highlight("firstMessage", (255, 204, 0), "bubble.left", "First time chatter")


def gigantified_emote_highlight() -> dict:
    return highlight(
        "gigantifiedEmote",
        (175, 82, 222),
        "arrow.up.backward.and.arrow.down.forward.square",
        "Gigantified emote",
    )


def announcement_highlight() -> dict:
    return highlight("other", (52, 199, 89), "horn.blast", "Announcement")


def super_sticker_highlight(amount: str = "$5.00") -> dict:
    title = "Super Sticker" if not amount else f"Super Sticker, {amount}"
    return highlight("other", (52, 199, 89), "doc.plaintext", title)


def super_chat_highlight(amount: str = "$5.00") -> dict:
    title = "Super Chat" if not amount else f"Super Chat, {amount}"
    return highlight("other", (255, 149, 0), "message", title)
