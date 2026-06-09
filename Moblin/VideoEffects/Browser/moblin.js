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
      // `message` is a binary string (one byte per char) from atob(); decode it
      // back to UTF-8 so non-ASCII characters (accents, etc.) survive.
      const bytes = Uint8Array.from(message, (c) => c.charCodeAt(0));
      const json = new TextDecoder().decode(bytes);
      this.onmessage(JSON.parse(json).message.data);
    }
  }

  send(message) {
    window.webkit.messageHandlers.moblin.postMessage(JSON.stringify(message));
  }
}

const moblin = new Moblin();
