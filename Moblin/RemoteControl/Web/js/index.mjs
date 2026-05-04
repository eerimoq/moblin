import {
  appendToRow,
  getTableBodyNoHead,
  addOnChange,
  addOnClick,
  websocketUrl,
  connectionStatus,
  updateConnectionStatus,
} from "./utils.mjs";

const filterNames = {
  pixellate: "Pixellate",
  movie: "Movie",
  grayScale: "Gray scale",
  sepia: "Sepia",
  triple: "Triple",
  twin: "Twin",
  fourThree: "4:3",
  crt: "CRT",
  pinch: "Pinch",
  whirlpool: "Whirlpool",
  poll: "Poll",
  blurFaces: "Blur faces",
  privacy: "Blur background",
  beauty: "Beauty",
  moblinInMouth: "Moblin in mouth",
  cameraMan: "Camera man",
};

const allFilterKeys = [
  "pixellate",
  "movie",
  "grayScale",
  "sepia",
  "triple",
  "twin",
  "fourThree",
  "crt",
  "pinch",
  "whirlpool",
  "poll",
  "blurFaces",
  "privacy",
  "beauty",
  "moblinInMouth",
  "cameraMan",
];

let filterStates = {};
let lastKnownSceneId = null;
let lastKnownAutoSceneSwitcherId = null;
let lastKnownMicId = null;
let lastKnownBitrateId = null;

function formatBytesPerSecond(bps) {
  if (bps >= 1000000) {
    return (bps / 1000000).toFixed(1) + " Mbps";
  } else if (bps >= 1000) {
    return (bps / 1000).toFixed(0) + " Kbps";
  }
  return bps + " bps";
}

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
      this.sendGetSettingsRequest();
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
    updateConnectionStatus(connection.status);
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
    if (data.getSettings) {
      this.handleGetSettingsResponse(data.getSettings);
    }
  }

  handleGetStatusResponse(status) {
    updateStatus(status);
    this.statusTimerId = setTimeout(() => {
      this.sendGetStatusRequest();
    }, 1000);
  }

  handleGetSettingsResponse(settingsData) {
    populateSettings(settingsData.data);
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
    if (state.data.zoom !== undefined) {
      setZoom(state.data.zoom);
    }
    if (state.data.scene !== undefined) {
      setScene(state.data.scene);
    }
    if (state.data.mic !== undefined) {
      setMic(state.data.mic);
    }
    if (state.data.bitrate !== undefined) {
      setBitrate(state.data.bitrate);
    }
    if (state.data.zoomPreset !== undefined) {
      setZoomPreset(state.data.zoomPreset);
    }
    if (state.data.zoomPresets !== undefined) {
      populateZoomPresets(state.data.zoomPresets, state.data.zoomPreset);
    }
    if (state.data.autoSceneSwitcher !== undefined) {
      setAutoSceneSwitcher(state.data.autoSceneSwitcher ? state.data.autoSceneSwitcher.id : null);
    }
    if (state.data.filters !== undefined) {
      updateFilterStates(state.data.filters);
    }
  }

  handleLogEvent(log) {
    let entry = document.createElement("div");
    entry.textContent = log.entry;
    document.getElementById("log").appendChild(entry);
  }

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

function appendStatusRow(body, name, value) {
  let row = body.insertRow(-1);
  row.className = "border-b border-zinc-800";
  appendToRow(row, name, "py-1.5 pr-4 text-zinc-200 font-medium whitespace-nowrap");
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

function populateSettings(settingsData) {
  document.getElementById("controlSection").classList.remove("hidden");
  let sceneSelect = document.getElementById("controlScene");
  sceneSelect.innerHTML = "";
  for (const scene of settingsData.scenes) {
    let option = document.createElement("option");
    option.value = scene.id;
    option.textContent = scene.name;
    sceneSelect.appendChild(option);
  }
  let autoSceneSelect = document.getElementById("controlAutoSceneSwitcher");
  autoSceneSelect.innerHTML = "";
  let noneOption = document.createElement("option");
  noneOption.value = "";
  noneOption.textContent = "-- None --";
  autoSceneSelect.appendChild(noneOption);
  if (settingsData.autoSceneSwitchers) {
    for (const switcher of settingsData.autoSceneSwitchers) {
      let option = document.createElement("option");
      option.value = switcher.id;
      option.textContent = switcher.name;
      autoSceneSelect.appendChild(option);
    }
  }
  let micSelect = document.getElementById("controlMic");
  micSelect.innerHTML = "";
  for (const mic of settingsData.mics) {
    let option = document.createElement("option");
    option.value = mic.id;
    option.textContent = mic.name;
    micSelect.appendChild(option);
  }
  let bitrateSelect = document.getElementById("controlBitrate");
  bitrateSelect.innerHTML = "";
  for (const preset of settingsData.bitratePresets) {
    let option = document.createElement("option");
    option.value = preset.id;
    option.textContent = preset.bitrate > 0 ? formatBytesPerSecond(preset.bitrate) : "Unknown";
    bitrateSelect.appendChild(option);
  }
  if (lastKnownSceneId !== null) {
    document.getElementById("controlScene").value = lastKnownSceneId;
  }
  if (lastKnownAutoSceneSwitcherId !== null) {
    document.getElementById("controlAutoSceneSwitcher").value = lastKnownAutoSceneSwitcherId;
  }
  if (lastKnownMicId !== null) {
    document.getElementById("controlMic").value = lastKnownMicId;
  }
  if (lastKnownBitrateId !== null) {
    document.getElementById("controlBitrate").value = lastKnownBitrateId;
  }
  if (
    settingsData.srt &&
    settingsData.srt.connectionPriorities &&
    settingsData.srt.connectionPriorities.length > 0
  ) {
    document.getElementById("srtSection").classList.remove("hidden");
    document.getElementById("controlSrtEnabled").checked =
      settingsData.srt.connectionPrioritiesEnabled;
    populateSrtPriorities(settingsData.srt.connectionPriorities);
  }
  if (settingsData.gimbalPresets && settingsData.gimbalPresets.length > 0) {
    document.getElementById("gimbalSection").classList.remove("hidden");
    populateGimbalPresets(settingsData.gimbalPresets);
  }
  populateFilters();
}

function populateZoomPresets(presets, selectedId) {
  let container = document.getElementById("zoomPresets");
  container.innerHTML = "";
  if (!presets || presets.length === 0) {
    document.getElementById("zoomPresetsContainer").classList.add("hidden");
    return;
  }
  document.getElementById("zoomPresetsContainer").classList.remove("hidden");
  for (const preset of presets) {
    let btn = document.createElement("button");
    btn.textContent = preset.name;
    btn.dataset.id = preset.id;
    btn.className =
      preset.id === selectedId
        ? "bg-indigo-700 text-white text-sm px-3 py-1 rounded transition-colors"
        : "bg-zinc-700 hover:bg-zinc-600 text-zinc-200 text-sm px-3 py-1 rounded transition-colors";
    btn.addEventListener("click", () => {
      connection.setZoomPreset(preset.id);
    });
    container.appendChild(btn);
  }
}

function setZoomPreset(id) {
  let container = document.getElementById("zoomPresets");
  for (let btn of container.children) {
    if (btn.dataset.id === id) {
      btn.className = "bg-indigo-700 text-white text-sm px-3 py-1 rounded transition-colors";
    } else {
      btn.className =
        "bg-zinc-700 hover:bg-zinc-600 text-zinc-200 text-sm px-3 py-1 rounded transition-colors";
    }
  }
}

function populateSrtPriorities(priorities) {
  let container = document.getElementById("srtPriorities");
  container.innerHTML = "";
  for (const priority of priorities) {
    let div = document.createElement("div");
    div.className = "flex items-center space-x-3";

    let label = document.createElement("label");
    label.className = "text-sm text-zinc-200 w-24 shrink-0";
    label.textContent = priority.name;

    let checkbox = document.createElement("input");
    checkbox.type = "checkbox";
    checkbox.checked = priority.enabled;
    checkbox.className =
      "w-4 h-4 bg-zinc-800 border border-zinc-600 rounded cursor-pointer accent-indigo-600";
    checkbox.dataset.id = priority.id;

    let slider = document.createElement("input");
    slider.type = "range";
    slider.min = "0";
    slider.max = "9";
    slider.value = priority.priority;
    slider.className = "flex-1 accent-indigo-600";
    slider.dataset.id = priority.id;

    let valueLabel = document.createElement("span");
    valueLabel.className = "text-sm text-zinc-300 w-6 text-right";
    valueLabel.textContent = priority.priority;

    slider.addEventListener("change", () => {
      valueLabel.textContent = slider.value;
      connection.setSrtConnectionPriority(priority.id, parseInt(slider.value), checkbox.checked);
    });

    slider.addEventListener("input", () => {
      valueLabel.textContent = slider.value;
    });

    checkbox.addEventListener("change", () => {
      connection.setSrtConnectionPriority(priority.id, parseInt(slider.value), checkbox.checked);
    });

    div.appendChild(label);
    div.appendChild(checkbox);
    div.appendChild(slider);
    div.appendChild(valueLabel);
    container.appendChild(div);
  }
}

function populateGimbalPresets(presets) {
  let container = document.getElementById("gimbalPresets");
  container.innerHTML = "";
  for (const preset of presets) {
    let btn = document.createElement("button");
    btn.textContent = preset.name;
    btn.className =
      "bg-zinc-700 hover:bg-zinc-600 text-zinc-200 text-sm px-4 py-2 rounded transition-colors";
    btn.addEventListener("click", () => {
      connection.moveToGimbalPreset(preset.id);
    });
    container.appendChild(btn);
  }
}

function populateFilters() {
  document.getElementById("filtersSection").classList.remove("hidden");
  let container = document.getElementById("filterToggles");
  container.innerHTML = "";
  for (const key of allFilterKeys) {
    let label = document.createElement("label");
    label.className = "flex items-center cursor-pointer";

    let wrapper = document.createElement("div");
    wrapper.className = "relative flex items-center";

    let checkbox = document.createElement("input");
    checkbox.id = "filter_" + key;
    checkbox.type = "checkbox";
    checkbox.checked = filterStates[key] || false;
    checkbox.className =
      "peer appearance-none w-11 h-5 bg-slate-400 rounded-full checked:bg-indigo-800 cursor-pointer transition-colors duration-300";
    checkbox.setAttribute("role", "switch");

    let knob = document.createElement("label");
    knob.htmlFor = "filter_" + key;
    knob.className =
      "absolute top-0 left-0 w-5 h-5 bg-white rounded-full border border-indigo-300 shadow-sm transition-transform duration-300 peer-checked:translate-x-6 peer-checked:border-slate-800 cursor-pointer";

    let text = document.createElement("span");
    text.className = "ml-3 text-sm text-zinc-200";
    text.textContent = filterNames[key] || key;

    wrapper.appendChild(checkbox);
    wrapper.appendChild(knob);
    wrapper.appendChild(text);
    label.appendChild(wrapper);
    container.appendChild(label);

    checkbox.addEventListener("change", () => {
      filterStates[key] = checkbox.checked;
      connection.setFilter(key, checkbox.checked);
    });
  }
}

function updateFilterStates(filters) {
  for (let index = 0; index < filters.length; index += 2) {
    const name = Object.keys(filters[index])[0];
    const on = filters[index + 1];
    filterStates[name] = on;
    let checkbox = document.getElementById("filter_" + name);
    if (checkbox) {
      checkbox.checked = on;
    }
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

function setZoom(value) {
  document.getElementById("controlZoom").value = value;
}

function setScene(id) {
  lastKnownSceneId = id;
  document.getElementById("controlScene").value = id;
}

function setMic(id) {
  lastKnownMicId = id;
  document.getElementById("controlMic").value = id;
}

function setBitrate(id) {
  lastKnownBitrateId = id;
  document.getElementById("controlBitrate").value = id;
}

function setAutoSceneSwitcher(id) {
  lastKnownAutoSceneSwitcherId = id || "";
  document.getElementById("controlAutoSceneSwitcher").value = id || "";
}

function handleZoomSubmit() {
  let value = parseFloat(document.getElementById("controlZoom").value);
  if (!isNaN(value)) {
    connection.setZoom(value);
  }
}

function handleSceneChange(event) {
  connection.setScene(event.target.value);
}

function handleAutoSceneSwitcherChange(event) {
  let value = event.target.value;
  connection.setAutoSceneSwitcher(value === "" ? null : value);
}

function handleMicChange(event) {
  connection.setMic(event.target.value);
}

function handleBitrateChange(event) {
  connection.setBitratePreset(event.target.value);
}

function handleSrtEnabledChange(event) {
  connection.setSrtConnectionPrioritiesEnabled(event.target.checked);
}

function handleReloadBrowserWidgets() {
  connection.reloadBrowserWidgets();
}

let connection = new Connection();

window.addEventListener("DOMContentLoaded", async () => {
  addOnChange("controlLive", toggleLive);
  addOnChange("controlRecording", toggleRecording);
  addOnChange("controlMuted", toggleMuted);
  addOnChange("controlDebugLogging", toggleDebugLogging);
  addOnChange("controlScene", handleSceneChange);
  addOnChange("controlAutoSceneSwitcher", handleAutoSceneSwitcherChange);
  addOnChange("controlMic", handleMicChange);
  addOnChange("controlBitrate", handleBitrateChange);
  addOnChange("controlSrtEnabled", handleSrtEnabledChange);
  addOnClick("reloadBrowserWidgets", handleReloadBrowserWidgets);

  let zoomInput = document.getElementById("controlZoom");
  zoomInput.addEventListener("keydown", (event) => {
    if (event.key === "Enter") {
      handleZoomSubmit();
    }
  });
  zoomInput.addEventListener("blur", handleZoomSubmit);
});
