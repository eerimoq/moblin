class Moblin {
  constructor() {
      this.timer = setInterval(() => {
          this.send({ping: {}})
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
      this.onmessage(JSON.parse(message).message.data);
    }
  }

  send(message) {
    window.webkit.messageHandlers.moblin.postMessage(JSON.stringify(message));
  }
}

const moblin = new Moblin();
