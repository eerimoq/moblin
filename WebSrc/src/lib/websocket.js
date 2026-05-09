import { websocketPort } from "/js/config.mjs";

export function websocketUrl() {
  return `ws://${window.location.hostname}:${websocketPort}`;
}

export const connectionStatus = {
  connecting: "Connecting...",
  connected: "Connected",
};

export class WebSocketConnection {
  constructor() {
    this.connectTimerId = undefined;
    this.nextId = 1;
    this.status = connectionStatus.connecting;
    this.connect();
  }

  connect() {
    this.websocket = new WebSocket(websocketUrl());
    this.websocket.onopen = () => {
      this.setStatus(connectionStatus.connected);
      this.onConnected();
    };
    this.websocket.onerror = () => {
      this.reconnectSoon();
    };
    this.websocket.onclose = () => {
      this.reconnectSoon();
    };
    this.websocket.onmessage = async (event) => {
      let message = JSON.parse(event.data);
      await this.handleMessage(message);
    };
  }

  reconnectSoon() {
    if (this.websocket != undefined) {
      this.websocket.close();
    }
    if (this.connectTimerId != undefined) {
      clearTimeout(this.connectTimerId);
    }
    this.setStatus(connectionStatus.connecting);
    this.connectTimerId = setTimeout(() => {
      this.connectTimerId = undefined;
      this.connect();
    }, 5000);
  }

  setStatus(newStatus) {
    if (this.status == newStatus) {
      return;
    }
    this.status = newStatus;
    this.onStatusChanged(this.status);
  }

  onConnected() {}

  onStatusChanged(_status) {}

  setLive(on) {
    this.sendRequest({ setStream: { on } });
  }

  setRecording(on) {
    this.sendRequest({ setRecord: { on } });
  }

  setMuted(on) {
    this.sendRequest({ setMute: { on } });
  }

  setDebugLogging(on) {
    this.sendRequest({ setDebugLogging: { on } });
  }

  setZoom(x) {
    this.sendRequest({ setZoom: { x } });
  }

  setZoomPreset(id) {
    this.sendRequest({ setZoomPreset: { id } });
  }

  setScene(id) {
    this.sendRequest({ setScene: { id } });
  }

  setAutoSceneSwitcher(id) {
    this.sendRequest({ setAutoSceneSwitcher: { id } });
  }

  setMic(id) {
    this.sendRequest({ setMic: { id } });
  }

  setBitratePreset(id) {
    this.sendRequest({ setBitratePreset: { id } });
  }

  sendGetGolfScoreboard() {
    this.sendRequest({ getGolfScoreboard: {} });
  }

  reloadBrowserWidgets() {
    this.sendRequest("reloadBrowserWidgets");
  }

  setSrtConnectionPrioritiesEnabled(enabled) {
    this.sendRequest({ setSrtConnectionPrioritiesEnabled: { enabled } });
  }

  setSrtConnectionPriority(id, priority, enabled) {
    this.sendRequest({ setSrtConnectionPriority: { id, priority, enabled } });
  }

  moveToGimbalPreset(id) {
    this.sendRequest({ moveToGimbalPreset: { id } });
  }

  setFilter(filter, on) {
    this.sendRequest({ setFilter: { filter: { [filter]: {} }, on } });
  }

  getNextId() {
    this.nextId += 1;
    return this.nextId;
  }

  async handleMessage(message) {
    if (message.ping) {
      this.handlePing();
    } else if (message.response) {
      this.handleResponse(message.response.id, message.response.result, message.response.data);
    } else if (message.event) {
      this.handleEvent(message.event.data);
    }
  }

  handlePing() {
    this.send({ pong: {} });
  }

  handleResponse(_id, _result, _data) {}

  handleEvent(_data) {}

  sendGetStatusRequest() {
    this.sendRequest({ getStatus: {} });
  }

  sendGetSettingsRequest() {
    this.sendRequest({ getSettings: {} });
  }

  sendStartStatusRequest() {
    this.sendRequest({
      startStatus: {
        interval: 1,
        filter: { topRight: true },
      },
    });
  }

  sendRequest(data) {
    this.send({
      request: {
        id: this.getNextId(),
        data: data,
      },
    });
  }

  send(message) {
    this.websocket.send(JSON.stringify(message));
  }
}
