class Moblin {
  constructor() {
    this.onmessage = null;
  }

  subscribe(data) {
    this.send({ subscribe: { data: data } });
  }

  handleMessage(message) {
    if (this.onmessage) {
      this.onmessage(JSON.parse(message).message);
    }
  }

  handleMessageMessage(message) {
    if (this.onmessage) {
      this.onmessage(message);
    }
  }

  send(message) {
    window.webkit.messageHandlers.moblin.postMessage(JSON.stringify(message));
  }
}

const moblin = new Moblin();