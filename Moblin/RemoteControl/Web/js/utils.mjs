import { websocketPort } from "./config.mjs";

export function getTableBodyNoHead(id) {
  let table = document.getElementById(id);
  while (table.rows.length > 0) {
    table.deleteRow(-1);
  }
  return table.tBodies[0];
}

export function appendToRow(row, value, className) {
  let cell = row.insertCell(-1);
  cell.innerHTML = value;
  if (className) {
    cell.className = className;
  }
}

export function addOnChange(elementId, func) {
  document.getElementById(elementId).addEventListener("change", func);
}

export function addOnClick(elementId, func) {
  document.getElementById(elementId).addEventListener("click", func);
}

export function addOnBlur(elementId, func) {
  document.getElementById(elementId).addEventListener("blur", func);
}

export function websocketUrl() {
  return `ws://${window.location.hostname}:${websocketPort}`;
}

let confirmComplete = null;
let confirmResult = false;

export async function confirm(message) {
  document.getElementById("confirm-message").textContent = message;
  const dialog = document.getElementById("confirm");
  dialog.showModal();
  await new Promise((resolve) => {
    confirmComplete = (result) => {
      confirmResult = result;
      resolve();
    };
  });
  dialog.close();
  return confirmResult;
}

export function confirmOk() {
  confirmComplete(true);
}

export function confirmCancel() {
  confirmComplete(false);
}

export const connectionStatus = {
  connecting: "Connecting...",
  connected: "Connected",
};

export function updateConnectionStatus(currentStatus) {
  let status = '<span class="text-red-500">Unknown server status</span>';
  if (currentStatus == connectionStatus.connecting) {
    status = '<span class="text-yellow-400">Connecting to server</span>';
  } else if (currentStatus == connectionStatus.connected) {
    status = '<span class="text-green-500">Connected to server</span>';
  }
  document.getElementById("status").innerHTML = status;
}

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
    updateConnectionStatus(this.status);
  }

  setLive(on) {
    this.sendRequest({
      setStream: {
        on: on,
      },
    });
  }

  setRecording(on) {
    this.sendRequest({
      setRecord: {
        on: on,
      },
    });
  }

  setMuted(on) {
    this.sendRequest({
      setMute: {
        on: on,
      },
    });
  }

  setDebugLogging(on) {
    this.sendRequest({
      setDebugLogging: {
        on: on,
      },
    });
  }

  setZoom(x) {
    this.sendRequest({
      setZoom: {
        x: x,
      },
    });
  }

  setZoomPreset(id) {
    this.sendRequest({
      setZoomPreset: {
        id: id,
      },
    });
  }

  setScene(id) {
    this.sendRequest({
      setScene: {
        id: id,
      },
    });
  }

  setAutoSceneSwitcher(id) {
    this.sendRequest({
      setAutoSceneSwitcher: {
        id: id,
      },
    });
  }

  setMic(id) {
    this.sendRequest({
      setMic: {
        id: id,
      },
    });
  }

  setBitratePreset(id) {
    this.sendRequest({
      setBitratePreset: {
        id: id,
      },
    });
  }

  sendGetGolfScoreboard() {
    this.sendRequest({ getGolfScoreboard: {} });
  }

  reloadBrowserWidgets() {
    this.sendRequest("reloadBrowserWidgets");
  }

  setSrtConnectionPrioritiesEnabled(enabled) {
    this.sendRequest({
      setSrtConnectionPrioritiesEnabled: {
        enabled: enabled,
      },
    });
  }

  setSrtConnectionPriority(id, priority, enabled) {
    this.sendRequest({
      setSrtConnectionPriority: {
        id: id,
        priority: priority,
        enabled: enabled,
      },
    });
  }

  moveToGimbalPreset(id) {
    this.sendRequest({
      moveToGimbalPreset: {
        id: id,
      },
    });
  }

  setFilter(filter, on) {
    this.sendRequest({
      setFilter: {
        filter: { [filter]: {} },
        on: on,
      },
    });
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
    this.sendRequest({
      getStatus: {},
    });
  }

  sendGetSettingsRequest() {
    this.sendRequest({
      getSettings: {},
    });
  }

  sendStartStatusRequest() {
    this.sendRequest({
      startStatus: {
        interval: 1,
        filter: {
          topRight: true,
        },
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
