import { appendToRow, getTableBodyNoHead, addOnChange } from "./utils.mjs";
import { websocketPort } from "./config.mjs";

class Connection {
  constructor() {
    this.statusTimerId = undefined;
    this.connectTimerId = undefined;
    this.nextId = 1;
    this.connect();
  }

  connect() {
    this.websocket = new WebSocket(
      `ws://${window.location.hostname}:${websocketPort}`,
    );
    this.websocket.onopen = (event) => {
      this.sendStartStatusRequest();
      this.sendGetStatusRequest();
    };
    this.websocket.onerror = (event) => {
      this.reconnectSoon();
    };
    this.websocket.onclose = (event) => {
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
    this.connectTimerId = setTimeout(() => {
      this.connectTimerId = undefined;
      this.connect();
    }, 5000);
  }

  setLive(on) {
    this.send({
      request: {
        id: this.getNextId(),
        data: {
          setStream: {
            on: on,
          },
        },
      },
    });
  }

  setRecording(on) {
    this.send({
      request: {
        id: this.getNextId(),
        data: {
          setRecord: {
            on: on,
          },
        },
      },
    });
  }

  setMuted(on) {
    this.send({
      request: {
        id: this.getNextId(),
        data: {
          setMute: {
            on: on,
          },
        },
      },
    });
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
    if (state.data.debugLogging !== undefined) {
      setDebugLogging(state.data.debugLogging);
    }
    if (state.data.streaming !== undefined) {
      setLive(state.data.streaming);
    }
    if (state.data.recording !== undefined) {
      setRecording(state.data.recording);
    }
    if (state.data.muted !== undefined) {
      setMuted(state.data.muted);
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

  sendStartStatusRequest() {
    this.send({
      request: {
        id: this.getNextId(),
        data: {
          startStatus: {
            interval: 1,
            filter: {
              topRight: true,
            },
          },
        },
      },
    });
  }

  send(message) {
    // console.log("Sending", message);
    this.websocket.send(JSON.stringify(message));
  }
}

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

window.addEventListener("DOMContentLoaded", async (event) => {
  addOnChange("controlLive", toggleLive);
  addOnChange("controlRecording", toggleRecording);
  addOnChange("controlMuted", toggleMuted);
  addOnChange("controlDebugLogging", toggleDebugLogging);
});
