import { createSignal, For, Show, onMount } from "solid-js";
import { createStore } from "solid-js/store";
import { render } from "solid-js/web";
import { WebSocketConnection } from "./utils.js";

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

const statusKeyToName = {
  camera: "Camera",
  chat: "Chat",
  mic: "Mic",
  stream: "Stream",
  zoom: "Zoom",
  obs: "OBS",
  events: "Events",
  viewers: "Viewers",
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

function formatBytesPerSecond(bps) {
  if (bps >= 1000000) return (bps / 1000000).toFixed(1) + " Mbps";
  if (bps >= 1000) return (bps / 1000).toFixed(0) + " Kbps";
  return bps + " bps";
}

function ToggleSwitch({ id, checked, onChange, label }) {
  return (
    <label class="flex items-center cursor-pointer">
      <div class="relative flex items-center">
        <input
          id={id}
          type="checkbox"
          class="peer appearance-none w-11 h-5 bg-slate-400 rounded-full checked:bg-indigo-800 cursor-pointer transition-colors duration-300"
          checked={checked}
          role="switch"
          onChange={onChange}
        />
        <label
          for={id}
          class="absolute top-0 left-0 w-5 h-5 bg-white rounded-full border border-indigo-300 shadow-sm transition-transform duration-300 peer-checked:translate-x-6 peer-checked:border-slate-800 cursor-pointer"
        />
        <span class="ml-3 text-sm text-zinc-200">{label}</span>
      </div>
    </label>
  );
}

function StatusTable({ rows }) {
  return (
    <div class="overflow-x-auto">
      <table class="w-full text-sm text-left text-zinc-300 table-auto">
        <tbody>
          <For each={rows()}>
            {([name, value]) => (
              <tr class="border-b border-zinc-800">
                <td class="py-1.5 pr-4 text-zinc-200 font-medium whitespace-nowrap">
                  {name}
                </td>
                <td class="py-1.5 text-zinc-200" innerHTML={value} />
              </tr>
            )}
          </For>
        </tbody>
      </table>
    </div>
  );
}

function App() {
  const [connStatus, setConnStatus] = createSignal("connecting");
  const [generalRows, setGeneralRows] = createSignal([]);
  const [topLeftRows, setTopLeftRows] = createSignal([]);
  const [topRightRows, setTopRightRows] = createSignal([]);

  // Control visibility
  const [showControl, setShowControl] = createSignal(false);
  const [showSrt, setShowSrt] = createSignal(false);
  const [showGimbal, setShowGimbal] = createSignal(false);
  const [showFilters, setShowFilters] = createSignal(false);

  // Control state
  const [liveOn, setLiveOn] = createSignal(false);
  const [recordingOn, setRecordingOn] = createSignal(false);
  const [mutedOn, setMutedOn] = createSignal(false);
  const [debugLoggingOn, setDebugLoggingOn] = createSignal(false);
  const [zoomValue, setZoomValue] = createSignal("");
  const [zoomPresets, setZoomPresets] = createSignal([]);
  const [currentZoomPresetId, setCurrentZoomPresetId] = createSignal(null);

  // Settings selects
  const [scenes, setScenes] = createSignal([]);
  const [currentSceneId, setCurrentSceneId] = createSignal("");
  const [autoSwitchers, setAutoSwitchers] = createSignal([]);
  const [currentAutoSwitcherId, setCurrentAutoSwitcherId] = createSignal("");
  const [mics, setMics] = createSignal([]);
  const [currentMicId, setCurrentMicId] = createSignal("");
  const [bitratePresets, setBitratePresets] = createSignal([]);
  const [currentBitrateId, setCurrentBitrateId] = createSignal("");

  // SRT
  const [srtEnabled, setSrtEnabled] = createSignal(false);
  const [srtPriorities, setSrtPriorities] = createStore([]);

  // Gimbal
  const [gimbalPresets, setGimbalPresets] = createSignal([]);

  // Filters
  const [filterStates, setFilterStates] = createStore({});

  // Log
  const [logEntries, setLogEntries] = createSignal([]);

  let logContainer;

  class IndexConnection extends WebSocketConnection {
    constructor() {
      super();
      this.statusTimerId = undefined;
    }

    onStatusChanged(newStatus) {
      if (newStatus === "Connected") {
        setConnStatus("connected");
      } else {
        setConnStatus("connecting");
      }
    }

    onConnected() {
      this.sendStartStatusRequest();
      this.sendGetStatusRequest();
      this.sendGetSettingsRequest();
    }

    reconnectSoon() {
      if (this.statusTimerId !== undefined) {
        clearTimeout(this.statusTimerId);
        this.statusTimerId = undefined;
      }
      setConnStatus("connecting");
      super.reconnectSoon();
    }

    handleResponse(_id, result, data) {
      if (!result.ok) return;
      if (!data) return;
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
        const entry = document.createElement("div");
        entry.textContent = data.log.entry;
        if (logContainer) logContainer.appendChild(entry);
      }
    }

    handleStateEvent(state) {
      if (state.data.streaming !== undefined) setLiveOn(state.data.streaming);
      if (state.data.recording !== undefined) setRecordingOn(state.data.recording);
      if (state.data.muted !== undefined) setMutedOn(state.data.muted);
      if (state.data.debugLogging !== undefined) setDebugLoggingOn(state.data.debugLogging);
      if (state.data.zoom !== undefined) setZoomValue(String(state.data.zoom));
      if (state.data.scene !== undefined) {
        setCurrentSceneId(state.data.scene);
      }
      if (state.data.mic !== undefined) {
        setCurrentMicId(state.data.mic);
      }
      if (state.data.bitrate !== undefined) {
        setCurrentBitrateId(state.data.bitrate);
      }
      if (state.data.zoomPreset !== undefined) {
        setCurrentZoomPresetId(state.data.zoomPreset);
      }
      if (state.data.zoomPresets !== undefined) {
        setZoomPresets(state.data.zoomPresets);
        setCurrentZoomPresetId(state.data.zoomPreset ?? null);
      }
      if (state.data.autoSceneSwitcher !== undefined) {
        setCurrentAutoSwitcherId(
          state.data.autoSceneSwitcher ? state.data.autoSceneSwitcher.id : "",
        );
      }
      if (state.data.filters !== undefined) {
        const filters = state.data.filters;
        for (let i = 0; i < filters.length; i += 2) {
          const name = Object.keys(filters[i])[0];
          const on = filters[i + 1];
          setFilterStates(name, on);
        }
      }
    }
  }

  const connection = new IndexConnection();

  function updateStatus(status) {
    const genRows = [
      ["Battery level", status.general.batteryLevel],
      ["Muted", String(status.general.isMuted)],
      ["Flame", status.general.flame],
      ["WiFi", status.general.wiFiSsid],
    ];
    setGeneralRows(genRows);

    const tlRows = Object.keys(status.topLeft)
      .sort()
      .filter((k) => statusKeyToName[k])
      .map((k) => [statusKeyToName[k], status.topLeft[k].message]);
    setTopLeftRows(tlRows);

    const trRows = Object.keys(status.topRight)
      .sort()
      .filter((k) => statusKeyToName[k])
      .map((k) => [statusKeyToName[k], status.topRight[k].message]);
    setTopRightRows(trRows);
  }

  function populateSettings(data) {
    setShowControl(true);
    setScenes(data.scenes ?? []);
    setAutoSwitchers(data.autoSceneSwitchers ?? []);
    setMics(data.mics ?? []);
    setBitratePresets(data.bitratePresets ?? []);

    if (data.srt?.connectionPriorities?.length > 0) {
      setShowSrt(true);
      setSrtEnabled(data.srt.connectionPrioritiesEnabled);
      setSrtPriorities(data.srt.connectionPriorities);
    }
    if (data.gimbalPresets?.length > 0) {
      setShowGimbal(true);
      setGimbalPresets(data.gimbalPresets);
    }
    setShowFilters(true);
  }

  function handleZoomSubmit() {
    const value = parseFloat(zoomValue());
    if (!isNaN(value)) connection.setZoom(value);
  }

  return (
    <div class="max-w-3xl mx-auto space-y-2">
      <h1 class="text-2xl font-bold text-center">Moblin Remote Control</h1>

      <div class="text-center space-x-4">
        <a href="./remote.html" class="text-indigo-400 hover:text-indigo-300 text-sm">
          Scoreboard Control
        </a>
        <a href="./scoreboard.html" class="text-indigo-400 hover:text-indigo-300 text-sm">
          Scoreboard Display
        </a>
        <a href="./golf.html" class="text-indigo-400 hover:text-indigo-300 text-sm">
          Golf Scoreboard
        </a>
        <a href="./recordings.html" class="text-indigo-400 hover:text-indigo-300 text-sm">
          Recordings
        </a>
        <a
          href="https://github.com/eerimoq/moblin"
          target="_blank"
          class="text-indigo-400 hover:text-indigo-300 text-sm"
        >
          Github
        </a>
      </div>

      <div class="pb-1 text-center">
        <Show when={connStatus() === "connected"}>
          <span class="text-green-500 text-sm">Connected to server</span>
        </Show>
        <Show when={connStatus() === "connecting"}>
          <span class="text-yellow-400 text-sm">Connecting to server</span>
        </Show>
      </div>

      {/* Status section */}
      <div class="bg-zinc-900 border border-zinc-700 rounded-lg p-2">
        <h2 class="text-xl font-semibold mb-3">Status</h2>
        <h3 class="text-base font-medium text-zinc-300 mb-1">General</h3>
        <StatusTable rows={generalRows} />
        <h3 class="text-base font-medium text-zinc-300 mt-3 mb-1">Top left</h3>
        <StatusTable rows={topLeftRows} />
        <h3 class="text-base font-medium text-zinc-300 mt-3 mb-1">Top right</h3>
        <StatusTable rows={topRightRows} />
      </div>

      {/* Control section */}
      <div class="bg-zinc-900 border border-zinc-700 rounded-lg p-2">
        <h2 class="text-xl font-semibold mb-3">Control</h2>
        <Show when={showControl()}>
          <div class="space-y-3">
            <ToggleSwitch
              id="controlLive"
              checked={liveOn()}
              onChange={(e) => connection.setLive(e.target.checked)}
              label="Live"
            />
            <ToggleSwitch
              id="controlRecording"
              checked={recordingOn()}
              onChange={(e) => connection.setRecording(e.target.checked)}
              label="Recording"
            />
            <ToggleSwitch
              id="controlMuted"
              checked={mutedOn()}
              onChange={(e) => connection.setMuted(e.target.checked)}
              label="Muted"
            />

            {/* Zoom */}
            <div class="flex items-center space-x-4">
              <label class="text-sm text-zinc-200 w-24 shrink-0">Zoom</label>
              <input
                type="text"
                class="bg-zinc-800 border border-zinc-600 rounded px-2 py-1 text-sm text-zinc-200 w-20"
                placeholder="1.0"
                value={zoomValue()}
                onInput={(e) => setZoomValue(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === "Enter") handleZoomSubmit();
                }}
                onBlur={handleZoomSubmit}
              />
            </div>

            {/* Zoom presets */}
            <Show when={zoomPresets().length > 0}>
              <div class="flex flex-wrap gap-2">
                <For each={zoomPresets()}>
                  {(preset) => (
                    <button
                      class={
                        preset.id === currentZoomPresetId()
                          ? "bg-indigo-700 text-white text-sm px-3 py-1 rounded transition-colors"
                          : "bg-zinc-700 hover:bg-zinc-600 text-zinc-200 text-sm px-3 py-1 rounded transition-colors"
                      }
                      onClick={() => connection.setZoomPreset(preset.id)}
                    >
                      {preset.name}
                    </button>
                  )}
                </For>
              </div>
            </Show>

            {/* Scene select */}
            <div class="flex items-center space-x-4">
              <label class="text-sm text-zinc-200 w-24 shrink-0">Scene</label>
              <select
                class="bg-zinc-800 border border-zinc-600 rounded px-2 py-1 text-sm text-zinc-200 flex-1"
                value={currentSceneId()}
                onChange={(e) => connection.setScene(e.target.value)}
              >
                <For each={scenes()}>
                  {(scene) => <option value={scene.id}>{scene.name}</option>}
                </For>
              </select>
            </div>

            {/* Auto scene switcher */}
            <div class="flex items-center space-x-4">
              <label class="text-sm text-zinc-200 w-24 shrink-0">Auto scene</label>
              <select
                class="bg-zinc-800 border border-zinc-600 rounded px-2 py-1 text-sm text-zinc-200 flex-1"
                value={currentAutoSwitcherId()}
                onChange={(e) => {
                  const val = e.target.value;
                  connection.setAutoSceneSwitcher(val === "" ? null : val);
                }}
              >
                <option value="">-- None --</option>
                <For each={autoSwitchers()}>
                  {(switcher) => (
                    <option value={switcher.id}>{switcher.name}</option>
                  )}
                </For>
              </select>
            </div>

            {/* Mic select */}
            <div class="flex items-center space-x-4">
              <label class="text-sm text-zinc-200 w-24 shrink-0">Mic</label>
              <select
                class="bg-zinc-800 border border-zinc-600 rounded px-2 py-1 text-sm text-zinc-200 flex-1"
                value={currentMicId()}
                onChange={(e) => connection.setMic(e.target.value)}
              >
                <For each={mics()}>
                  {(mic) => <option value={mic.id}>{mic.name}</option>}
                </For>
              </select>
            </div>

            {/* Bitrate select */}
            <div class="flex items-center space-x-4">
              <label class="text-sm text-zinc-200 w-24 shrink-0">Bitrate</label>
              <select
                class="bg-zinc-800 border border-zinc-600 rounded px-2 py-1 text-sm text-zinc-200 flex-1"
                value={currentBitrateId()}
                onChange={(e) => connection.setBitratePreset(e.target.value)}
              >
                <For each={bitratePresets()}>
                  {(preset) => (
                    <option value={preset.id}>
                      {preset.bitrate > 0
                        ? formatBytesPerSecond(preset.bitrate)
                        : "Unknown"}
                    </option>
                  )}
                </For>
              </select>
            </div>

            <ToggleSwitch
              id="controlDebugLogging"
              checked={debugLoggingOn()}
              onChange={(e) => connection.setDebugLogging(e.target.checked)}
              label="Debug logging"
            />

            <div class="flex flex-wrap gap-2">
              <button
                class="bg-zinc-700 hover:bg-zinc-600 text-zinc-200 text-sm px-3 py-1 rounded transition-colors"
                onClick={() => connection.reloadBrowserWidgets()}
              >
                Reload browser widgets
              </button>
            </div>
          </div>
        </Show>
      </div>

      {/* SRT section */}
      <Show when={showSrt()}>
        <div class="bg-zinc-900 border border-zinc-700 rounded-lg p-2">
          <h2 class="text-xl font-semibold mb-3">SRT Connection Priorities</h2>
          <ToggleSwitch
            id="controlSrtEnabled"
            checked={srtEnabled()}
            onChange={(e) => {
              setSrtEnabled(e.target.checked);
              connection.setSrtConnectionPrioritiesEnabled(e.target.checked);
            }}
            label="Enabled"
          />
          <div class="space-y-2 mt-3">
            <For each={srtPriorities}>
              {(priority, i) => (
                <SrtPriorityRow
                  priority={priority}
                  onChange={(p, en) => {
                    setSrtPriorities(i(), "priority", p);
                    setSrtPriorities(i(), "enabled", en);
                    connection.setSrtConnectionPriority(priority.id, p, en);
                  }}
                />
              )}
            </For>
          </div>
        </div>
      </Show>

      {/* Gimbal section */}
      <Show when={showGimbal()}>
        <div class="bg-zinc-900 border border-zinc-700 rounded-lg p-2">
          <h2 class="text-xl font-semibold mb-3">Gimbal Presets</h2>
          <div class="flex flex-wrap gap-2">
            <For each={gimbalPresets()}>
              {(preset) => (
                <button
                  class="bg-zinc-700 hover:bg-zinc-600 text-zinc-200 text-sm px-4 py-2 rounded transition-colors"
                  onClick={() => connection.moveToGimbalPreset(preset.id)}
                >
                  {preset.name}
                </button>
              )}
            </For>
          </div>
        </div>
      </Show>

      {/* Filters section */}
      <Show when={showFilters()}>
        <div class="bg-zinc-900 border border-zinc-700 rounded-lg p-2">
          <h2 class="text-xl font-semibold mb-3">Filters</h2>
          <div class="space-y-3">
            <For each={allFilterKeys}>
              {(key) => (
                <ToggleSwitch
                  id={`filter_${key}`}
                  checked={filterStates[key] || false}
                  onChange={(e) => {
                    setFilterStates(key, e.target.checked);
                    connection.setFilter(key, e.target.checked);
                  }}
                  label={filterNames[key] || key}
                />
              )}
            </For>
          </div>
        </div>
      </Show>

      {/* Log section */}
      <div class="bg-zinc-900 border border-zinc-700 rounded-lg p-2">
        <h2 class="text-xl font-semibold mb-3">Log</h2>
        <div ref={logContainer} class="overflow-y-auto h-96 text-sm text-zinc-300" />
      </div>
    </div>
  );
}

function SrtPriorityRow({ priority, onChange }) {
  const [sliderValue, setSliderValue] = createSignal(priority.priority);
  const [checked, setChecked] = createSignal(priority.enabled);

  return (
    <div class="flex items-center space-x-3">
      <label class="text-sm text-zinc-200 w-24 shrink-0">{priority.name}</label>
      <input
        type="checkbox"
        checked={checked()}
        class="w-4 h-4 bg-zinc-800 border border-zinc-600 rounded cursor-pointer accent-indigo-600"
        onChange={(e) => {
          setChecked(e.target.checked);
          onChange(sliderValue(), e.target.checked);
        }}
      />
      <input
        type="range"
        min="0"
        max="9"
        value={sliderValue()}
        class="flex-1 accent-indigo-600"
        onInput={(e) => setSliderValue(parseInt(e.target.value))}
        onChange={(e) => onChange(parseInt(e.target.value), checked())}
      />
      <span class="text-sm text-zinc-300 w-6 text-right">{sliderValue()}</span>
    </div>
  );
}

render(() => <App />, document.getElementById("app"));
