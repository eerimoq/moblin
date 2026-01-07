import {
  randomString,
  wsScheme,
  hashPassword,
  appendToRow,
  getTableBodyNoHead,
  addOnClick,
  addOnChange,
  relayStatus,
  connectionStatus,
} from "./utils.mjs";

const baseUrl = `${window.location.host}`;
const basePath = ``;

let streamerName = undefined;
let password = undefined;
let bridgeId = undefined;
let timerId = undefined;

class Connection {
  constructor(connectionId) {
    this.connectionId = connectionId;
    this.relayDataWebsocket = undefined;
    this.status = connectionStatus.connectingToRelay;
    this.statusTimerId = undefined;
    this.challenge = "";
    this.salt = "";
    this.streamerIdentified = false;
    this.nextId = 1;
  }

  close() {
    if (this.statusTimerId != undefined) {
      clearTimeout(this.statusTimerId);
      this.statusTimerId = undefined;
    }
    if (this.relayDataWebsocket != undefined) {
      this.relayDataWebsocket.close();
    }
    if (this.assistantWebsocket != undefined) {
      this.assistantWebsocket.close();
    }
  }

  setStatus(newStatus) {
    if (this.status == newStatus) {
      return;
    }
    if (this.isAborted() && newStatus != connectionStatus.rateLimitExceeded) {
      updateStreamerStatus();
      return;
    }
    this.status = newStatus;
    updateStreamerStatus();
  }

  isAborted() {
    return (
      this.status == connectionStatus.streamerClosed ||
      this.status == connectionStatus.streamerError ||
      this.status == connectionStatus.assistantClosed ||
      this.status == connectionStatus.assistantError ||
      this.status == connectionStatus.rateLimitExceeded
    );
  }

  setupRelayDataWebsocket() {
    this.relayDataWebsocket = new WebSocket(
      `${wsScheme}://${baseUrl}/bridge/data/${bridgeId}/${this.connectionId}`
    );
    this.status = connectionStatus.connectingToRelay;
    this.relayDataWebsocket.onopen = (event) => {
      this.challenge = randomString();
      this.salt = randomString();
      this.sendHello();
      this.streamerIdentified = false;
    };
    this.relayDataWebsocket.onerror = (event) => {
      this.setStatus(connectionStatus.streamerError);
      this.close();
    };
    this.relayDataWebsocket.onclose = (event) => {
      this.setStatus(connectionStatus.streamerClosed);
      this.close();
    };
    this.relayDataWebsocket.onmessage = async (event) => {
      let message = JSON.parse(event.data);
      await this.handleMessage(message);
    };
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
    } else if (message.identify) {
      await this.handleIdentify(message.identify);
    } else if (message.response) {
      this.handleResponse(
        message.response.id,
        message.response.result,
        message.response.data
      );
    } else if (message.event) {
      this.handleEvent(message.event.data);
    }
  }

  handlePing() {
    this.send({ pong: {} });
  }

  async handleIdentify(identify) {
    if (
      identify.authentication ==
      (await hashPassword(password, this.challenge, this.salt))
    ) {
      this.streamerIdentified = true;
      this.send({
        identified: {
          result: {
            ok: {},
          },
        },
      });
      this.setStatus(connectionStatus.connected);
      this.sendGetStatusRequest();
    } else {
      this.send({
        identified: {
          result: {
            wrongPassword: {},
          },
        },
      });
      this.close();
    }
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

  sendHello() {
    this.send({
      hello: {
        apiVersion: "1.0",
        authentication: {
          challenge: this.challenge,
          salt: this.salt,
        },
      },
    });
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
    this.relayDataWebsocket.send(JSON.stringify(message));
  }
}

class Relay {
  constructor() {
    this.controlWebsocket = undefined;
    this.status = relayStatus.connecting;
  }

  close() {
    if (this.controlWebsocket != undefined) {
      this.controlWebsocket.close();
      this.controlWebsocket = undefined;
    }
  }

  setStatus(newStatus) {
    if (this.status == newStatus) {
      return;
    }
    this.status = newStatus;
    updateRelayStatus();
  }

  setupControlWebsocket() {
    this.controlWebsocket = new WebSocket(
      `${wsScheme}://${baseUrl}/bridge/control/${bridgeId}`
    );
    this.setStatus(relayStatus.connecting);
    this.controlWebsocket.onopen = (event) => {
      this.setStatus(relayStatus.connected);
    };
    this.controlWebsocket.onerror = (event) => {
      if (this.status != relayStatus.kicked) {
        reset(10000);
      }
    };
    this.controlWebsocket.onclose = (event) => {
      if (this.status != relayStatus.kicked) {
        reset(10000);
      }
    };
    this.controlWebsocket.onmessage = async (event) => {
      let message = JSON.parse(event.data);
      if (message.type == "connect") {
        let connectionId = message.data.connectionId;
        if (connection != undefined) {
          connection.close();
        }
        connection = new Connection(connectionId);
        connection.setupRelayDataWebsocket();
      } else if (message.type == "kicked") {
        this.setStatus(relayStatus.kicked);
      } else if (message.type == "rateLimitExceeded") {
        if (connection != undefined) {
          connection.setStatus(connectionStatus.rateLimitExceeded);
        }
      }
    };
  }
}

let relay = undefined;
let connection = undefined;

function reset(delayMs) {
  if (connection != undefined) {
    connection.close();
    connection = undefined;
  }
  relay.close();
  relay = new Relay();
  if (timerId != undefined) {
    clearTimeout(timerId);
  }
  timerId = setTimeout(() => {
    timerId = undefined;
    relay.setupControlWebsocket();
  }, delayMs);
}

function makeStreamerUrl() {
  return `${wsScheme}://${baseUrl}/streamer/${bridgeId}`;
}

function makeAssistantUrl() {
  return `${basePath}/index.html?streamerName=${streamerName}`;
}

function copyStreamerUrlToClipboard() {
  navigator.clipboard.writeText(makeStreamerUrl());
}

function toggleShow(inputId, iconId) {
  let input = document.getElementById(inputId);
  let icon = document.getElementById(iconId);
  if (input.type === "password") {
    input.type = "text";
    icon.classList.add("p-icon--hide");
    icon.classList.remove("p-icon--show");
  } else {
    input.type = "password";
    icon.classList.add("p-icon--show");
    icon.classList.remove("p-icon--hide");
  }
}

function toggleShowMoblinStreamerAssistantUrl() {
  toggleShow("streamerAssistantUrl", "streamerAssistantUrlIcon");
}

function toggleShowStatusPageUrl() {
  toggleShow("statusPageUrl", "statusPageUrlIcon");
}

function populateRemoteControllerSetup() {
  document.getElementById("streamerAssistantUrl").value = makeStreamerUrl();
}

function populateSettings() {
  document.getElementById("streamerName").value = streamerName;
  document.getElementById("password").value = password;
  document.getElementById("bridgeId").value = bridgeId;
}

function makeLocalStorageBridgeIdKey(streamerNameArg) {
  return `bridgeId.${streamerNameArg ?? streamerName}`;
}

function makeLocalStoragePassword(streamerNameArg) {
  return `password.${streamerNameArg ?? streamerName}`;
}

function loadSettings() {
  streamerName = document.getElementById("loadStreamerSelector").value;
  password = localStorage.getItem(makeLocalStoragePassword());
  bridgeId = localStorage.getItem(makeLocalStorageBridgeIdKey());
  updateUrl();
  populateRemoteControllerSetup();
  populateSettings();
  updateStreamerStatus();
  clear();
  reset(0);
}

function deleteSettings() {
  const streamerName = document.getElementById("loadStreamerSelector").value;
  localStorage.removeItem(makeLocalStorageBridgeIdKey(streamerName));
  localStorage.removeItem(makeLocalStoragePassword(streamerName));
  populateStreamerSelector();
}

function populateStreamerSelector() {
  let loadStreamerSelector = document.getElementById("loadStreamerSelector");
  loadStreamerSelector.options.length = 0;
  for (const bridgeIdKey of getLocalStorageBridgeIdKeys()) {
    let option = document.createElement("option");
    option.text = getStreamerNameFromBridgeIdKey(bridgeIdKey);
    loadStreamerSelector.add(option);
  }
}

function getLocalStorageBridgeIdKeys() {
  return Object.keys(window.localStorage)
    .filter((key) => {
      return key.startsWith("bridgeId.");
    })
    .sort();
}

function getStreamerNameFromBridgeIdKey(bridgeIdKey) {
  return bridgeIdKey.split(".").slice(1).join(".");
}

function saveSettings() {
  streamerName = document.getElementById("streamerName").value;
  password = document.getElementById("password").value;
  localStorage.setItem(makeLocalStoragePassword(), password);
  bridgeId = document.getElementById("bridgeId").value;
  localStorage.setItem(makeLocalStorageBridgeIdKey(), bridgeId);
  updateUrl();
  populateRemoteControllerSetup();
  populateStreamerSelector();
  clear();
  reset(0);
}

function resetSettings() {
  regenerateBridgeId();
  localStorage.setItem(makeLocalStorageBridgeIdKey(), bridgeId);
  populateRemoteControllerSetup();
  populateSettings();
  reset(0);
}

function regenerateBridgeId() {
  bridgeId = crypto.randomUUID();
  document.getElementById("bridgeId").value = bridgeId;
}

function updateRelayStatus() {
  let status = '<i class="p-icon--error"></i> Unknown server status';
  if (relay.status == relayStatus.connecting) {
    status =
      '<i class="p-icon--spinner u-animation--spin"></i> Connecting to server';
  } else if (relay.status == relayStatus.connected) {
    status = '<i class="p-icon--success"></i> Connected to server';
  } else if (relay.status == relayStatus.kicked) {
    status = '<i class="p-icon--error"></i> Kicked by server';
  }
  document.getElementById("relayStatus").innerHTML = status;
}

function updateStreamerStatus() {
  let streamerStatus = `<i class="p-icon--spinner u-animation--spin"></i> Waiting for streamer (${streamerName}) to connect`;
  if (connection != undefined) {
    if (connection.status == connectionStatus.connected) {
      streamerStatus = `<i class="p-icon--success"></i> Connected to streamer (${streamerName})`;
    }
  }
  document.getElementById("streamerStatus").innerHTML = streamerStatus;
}

function toggleShowBridgeId() {
  let bridgeIdInput = document.getElementById("bridgeId");
  let bridgeIdText = document.getElementById("bridgeIdText");
  let bridgeIdIcon = document.getElementById("bridgeIdIcon");
  if (bridgeIdInput.type === "password") {
    bridgeIdInput.type = "text";
    bridgeIdText.innerText = "Hide";
    bridgeIdIcon.classList.add("p-icon--hide");
    bridgeIdIcon.classList.remove("p-icon--show");
  } else {
    bridgeIdInput.type = "password";
    bridgeIdText.innerText = "Show";
    bridgeIdIcon.classList.add("p-icon--show");
    bridgeIdIcon.classList.remove("p-icon--hide");
  }
}

function toggleShowPassword() {
  let passwordInput = document.getElementById("password");
  let passwordText = document.getElementById("passwordText");
  let passwordIcon = document.getElementById("passwordIcon");
  if (passwordInput.type === "password") {
    passwordInput.type = "text";
    passwordText.innerText = "Hide";
    passwordIcon.classList.add("p-icon--hide");
    passwordIcon.classList.remove("p-icon--show");
  } else {
    passwordInput.type = "password";
    passwordText.innerText = "Show";
    passwordIcon.classList.add("p-icon--show");
    passwordIcon.classList.remove("p-icon--hide");
  }
}

function loadStreamerName(urlParams) {
  streamerName = urlParams.get("streamerName");
  if (streamerName == undefined) {
    const bridgeIdKeys = getLocalStorageBridgeIdKeys();
    if (bridgeIdKeys.length > 0) {
      streamerName = getStreamerNameFromBridgeIdKey(bridgeIdKeys[0]);
    }
  }
  if (streamerName == undefined) {
    streamerName = "Anna";
  }
  updateStreamerStatus();
}

function loadPassword(urlParams) {
  password = urlParams.get("password");
  if (password == undefined) {
    password = localStorage.getItem(makeLocalStoragePassword());
  }
  if (password == undefined) {
    password = "";
  }
  localStorage.setItem(makeLocalStoragePassword(), password);
}

function loadBridgeId(urlParams) {
  bridgeId = urlParams.get("bridgeId");
  if (bridgeId == undefined) {
    bridgeId = localStorage.getItem(makeLocalStorageBridgeIdKey());
  }
  if (bridgeId == undefined) {
    bridgeId = crypto.randomUUID();
  }
  localStorage.setItem(makeLocalStorageBridgeIdKey(), bridgeId);
}

function updateUrl() {
  history.replaceState(history.state, "", makeAssistantUrl());
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

function clear() {
  getTableBodyNoHead("statusGeneral");
  getTableBodyNoHead("statusTopLeft");
  getTableBodyNoHead("statusTopRight");
  document.getElementById("log").innerHTML = "";
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
  const urlParams = new URLSearchParams(window.location.search);
  loadStreamerName(urlParams);
  loadPassword(urlParams);
  loadBridgeId(urlParams);
  updateUrl();
  relay = new Relay();
  relay.setupControlWebsocket();
});
