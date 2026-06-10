class Moblin {
  constructor() {
    this.timer = setInterval(() => {
      this.send({ ping: {} });
    }, 2000);
    this.onmessage = null;
  }

  publish(message) {
    this.send({ publish: { message: message } });
  }

  subscribe(topic) {
    this.send({ subscribe: { topic: topic } });
  }

  handleMessage(message) {
    if (this.onmessage) {
      // `message` is base64; decode straight to UTF-8 so non-ASCII characters
      // (accents, emoji, etc.) survive instead of being read as Latin-1.
      const json = new TextDecoder().decode(Uint8Array.fromBase64(message));
      this.onmessage(JSON.parse(json).message.data);
    }
  }

  send(message) {
    window.webkit.messageHandlers.moblin.postMessage(JSON.stringify(message));
  }
}

const moblin = new Moblin();
