import { appendToRow, getTableBodyNoHead, addOnChange, websocketUrl } from "./utils.mjs";

export const connectionStatus = {
  connecting: "Connecting...",
  connected: "Connected",
};

class Connection {
  constructor() {
    this.statusTimerId = undefined;
    this.connectTimerId = undefined;
    this.nextId = 1;
    this.status = connectionStatus.connecting;
    this.connect();
  }

  connect() {
    this.websocket = new WebSocket(websocketUrl());
    this.websocket.onopen = () => {
      this.setStatus(connectionStatus.connected);
      this.sendStartStatusRequest();
      this.sendGetStatusRequest();
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
    if (this.statusTimerId != undefined) {
      clearTimeout(this.statusTimerId);
      this.statusTimerId = undefined;
    }
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
    updateConnectionStatus();
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
    this.send({
      setMute: {
        on: on,
      },
    });
  }

  setDebugLogging(on) {
    this.send({
      setDebugLogging: {
        on: on,
      },
    });
  }

  getNextId() {
    this.nextId += 1;
    return this.nextId;
  }

  async handleMessage(message) {
    // console.log("Got", message);
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

  handleResponse(id, result, data) {
    if (!result.ok) {
      console.log("Unsuccessful request: ", result);
      return;
    }
    if (!data) {
      return;
    }
    if (data.getStatus) {
      this.handleGetStatusResponse(data.getStatus);
    }
  }

  handleGetStatusResponse(status) {
    updateStatus(status);
    this.statusTimerId = setTimeout(() => {
      this.sendGetStatusRequest();
    }, 1000);
  }

  handleEvent(data) {
    if (data.state) {
      this.handleStateEvent(data.state);
    } else if (data.log) {
      this.handleLogEvent(data.log);
    }
  }

  handleStateEvent(state) {
    if (state.data.streaming !== undefined) {
      setLive(state.data.streaming);
    }
    if (state.data.recording !== undefined) {
      setRecording(state.data.recording);
    }
    if (state.data.muted !== undefined) {
      setMuted(state.data.muted);
    }
    if (state.data.debugLogging !== undefined) {
      setDebugLogging(state.data.debugLogging);
    }
  }

  handleLogEvent(log) {
    let entry = document.createElement("div");
    entry.innerHTML = log.entry;
    document.getElementById("log").appendChild(entry);
  }

  sendGetStatusRequest() {
    this.sendRequest({
      getStatus: {},
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
    // console.log("Sending", message);
    this.websocket.send(JSON.stringify(message));
  }
}

function appendStatusRow(body, name, value) {
  let row = body.insertRow(-1);
  row.className = "border-b border-zinc-800";
  appendToRow(row, name, "py-1.5 pr-4 text-zinc-400 font-medium whitespace-nowrap");
  appendToRow(row, value, "py-1.5 text-zinc-200");
}

function updateStatus(status) {
  let generalBody = getTableBodyNoHead("statusGeneral");
  appendStatusRow(generalBody, "Battery level", status.general.batteryLevel);
  appendStatusRow(generalBody, "Muted", status.general.isMuted);
  appendStatusRow(generalBody, "Flame", status.general.flame);
  appendStatusRow(generalBody, "WiFi", status.general.wiFiSsid);
  let topLeftBody = getTableBodyNoHead("statusTopLeft");
  appendStatuses(topLeftBody, status.topLeft);
  let topRightBody = getTableBodyNoHead("statusTopRight");
  appendStatuses(topRightBody, status.topRight);
}

const statusKeyToName = {
  // Top left
  camera: "Camera",
  chat: "Chat",
  mic: "Mic",
  stream: "Stream",
  zoom: "Zoom",
  obs: "OBS",
  events: "Events",
  viewers: "Viewers",
  // Top right
  audioLevel: "Audio",
  location: "Location",
  moblink: "Moblink",
  remoteControl: "Remote control",
  rtmpServer: "RTMP/SRT(LA) servers",
  gameController: "Game controller",
  bitrate: "Bitrate",
  uptime: "Uptime",
  srtla: "Bonding",
  srtlaRtts: "Bonding RTT:s",
  recording: "Recording",
  browserWidgets: "Browser widgets",
  djiDevices: "DJI devices",
};

function appendStatuses(body, statuses) {
  for (const key of Object.keys(statuses).sort()) {
    const name = statusKeyToName[key];
    if (!name) {
      continue;
    }
    appendStatusRow(body, name, statuses[key].message);
  }
}

function updateConnectionStatus() {
  let status = '<span class="text-red-500">&#x2716; Unknown server status</span>';
  if (connection.status == connectionStatus.connecting) {
    status = '<span class="text-yellow-400">&#x25cf; Connecting to server</span>';
  } else if (connection.status == connectionStatus.connected) {
    status = '<span class="text-green-500">&#x2714; Connected to server</span>';
  }
  document.getElementById("status").innerHTML = status;
}

function toggleLive(event) {
  connection.setLive(event.target.checked);
}

function setLive(on) {
  document.getElementById("controlLive").checked = on;
}

function toggleRecording(event) {
  connection.setRecording(event.target.checked);
}

function setRecording(on) {
  document.getElementById("controlRecording").checked = on;
}

function toggleMuted(event) {
  connection.setMuted(event.target.checked);
}

function setMuted(on) {
  document.getElementById("controlMuted").checked = on;
}

function toggleDebugLogging(event) {
  connection.setDebugLogging(event.target.checked);
}

function setDebugLogging(on) {
  document.getElementById("controlDebugLogging").checked = on;
}

let connection = new Connection();

window.addEventListener("DOMContentLoaded", async () => {
  addOnChange("controlLive", toggleLive);
  addOnChange("controlRecording", toggleRecording);
  addOnChange("controlMuted", toggleMuted);
  addOnChange("controlDebugLogging", toggleDebugLogging);
});
