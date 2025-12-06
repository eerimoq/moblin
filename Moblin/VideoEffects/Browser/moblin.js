class Moblin {
  constructor() {
    this.onmessage = null;
  }

  subscribe(topic) {
    this.send({ subscribe: { topic: topic } });
  }

  handleMessage(message) {
    if (this.onmessage) {
      this.onmessage(JSON.parse(message).message.data);
    }
  }

  send(message) {
    window.webkit.messageHandlers.moblin.postMessage(JSON.stringify(message));
  }
}

const moblin = new Moblin();
