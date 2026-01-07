import {
  appendToRow,
  getTableBodyNoHead,
  addOnChange,
  connectionStatus,
} from "./utils.mjs";

class Connection {
  constructor() {
    this.websocket = undefined;
    this.statusTimerId = undefined;
    this.nextId = 1;
    this.setup();
  }

  setup() {
    this.websocket = new WebSocket(`ws://localhost:81`);
    this.websocket.onopen = (event) => {
      this.sendGetStatusRequest();
    };
    this.websocket.onerror = (event) => {
      this.close();
    };
    this.websocket.onclose = (event) => {
      this.close();
    };
    this.websocket.onmessage = async (event) => {
      let message = JSON.parse(event.data);
      await this.handleMessage(message);
    };
  }

  close() {
    if (this.statusTimerId != undefined) {
      clearTimeout(this.statusTimerId);
      this.statusTimerId = undefined;
    }
    if (this.websocket != undefined) {
      this.websocket.close();
    }
  }

  setDebugLogging(on) {
    this.send({
      request: {
        id: this.getNextId(),
        data: {
          setDebugLogging: {
            on: on,
          },
        },
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
      this.handleResponse(
        message.response.id,
        message.response.result,
        message.response.data,
      );
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
    }, 5000);
  }

  handleEvent(data) {
    if (data.state) {
      this.handleStateEvent(data.state);
    } else if (data.log) {
      this.handleLogEvent(data.log);
    }
  }

  handleStateEvent(state) {
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
    this.send({
      request: {
        id: this.getNextId(),
        data: {
          getStatus: {},
        },
      },
    });
  }

  send(message) {
    // console.log("Sending", message);
    this.websocket.send(JSON.stringify(message));
  }
}

let connection = undefined;

function updateStatus(status) {
  let generalBody = getTableBodyNoHead("statusGeneral");
  let row = generalBody.insertRow(-1);
  appendToRow(row, "Battery level");
  appendToRow(row, status.general.batteryLevel);
  row = generalBody.insertRow(-1);
  appendToRow(row, "Muted");
  appendToRow(row, status.general.isMuted);
  row = generalBody.insertRow(-1);
  appendToRow(row, "Flame");
  appendToRow(row, status.general.flame);
  row = generalBody.insertRow(-1);
  appendToRow(row, "WiFi");
  appendToRow(row, status.general.wiFiSsid);
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
    let row = body.insertRow(-1);
    appendToRow(row, name);
    appendToRow(row, statuses[key].message);
  }
}

function toggleDebugLogging(event) {
  if (connection === undefined) {
    return;
  }
  connection.setDebugLogging(event.target.checked);
}

function setDebugLogging(on) {
  document.getElementById("controlDebugLogging").checked = on;
}

window.addEventListener("DOMContentLoaded", async (event) => {
  addOnChange("controlDebugLogging", toggleDebugLogging);
  connection = new Connection();
});
