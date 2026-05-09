<svelte:head>
  <title>Moblin Remote Control</title>
  <link rel="icon" type="image/x-icon" href="favicon.ico" />
  <link rel="stylesheet" href="css/app.css" />
</svelte:head>

<script>
  import { WebSocketConnection, connectionStatus } from "./lib/websocket.js";

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

  // --- Reactive state ---
  let connStatus = $state(connectionStatus.connecting);
  let statusGeneral = $state([]);
  let statusTopLeft = $state([]);
  let statusTopRight = $state([]);
  let controlsVisible = $state(false);
  let scenes = $state([]);
  let autoSceneSwitchers = $state([]);
  let mics = $state([]);
  let bitratePresets = $state([]);
  let isLive = $state(false);
  let isRecording = $state(false);
  let isMuted = $state(false);
  let isDebugLogging = $state(false);
  let zoom = $state("");
  let selectedSceneId = $state("");
  let selectedAutoSceneSwitcherId = $state("");
  let selectedMicId = $state("");
  let selectedBitrateId = $state("");
  let zoomPresets = $state([]);
  let selectedZoomPresetId = $state(null);
  let srtVisible = $state(false);
  let srtEnabled = $state(false);
  let srtPriorities = $state([]);
  let gimbalVisible = $state(false);
  let gimbalPresets = $state([]);
  let filtersVisible = $state(false);
  let filterStates = $state({});
  let logEntries = $state([]);

  function updateStatus(s) {
    const g = s.general;
    statusGeneral = [
      { name: "Battery level", value: g.batteryLevel },
      { name: "Muted", value: g.isMuted },
      { name: "Flame", value: g.flame },
      { name: "WiFi", value: g.wiFiSsid },
    ];
    statusTopLeft = buildStatuses(s.topLeft);
    statusTopRight = buildStatuses(s.topRight);
  }

  function buildStatuses(statuses) {
    return Object.keys(statuses)
      .sort()
      .filter((k) => statusKeyToName[k])
      .map((k) => ({ name: statusKeyToName[k], value: statuses[k].message }));
  }

  function populateSettings(data) {
    controlsVisible = true;
    scenes = data.scenes || [];
    autoSceneSwitchers = data.autoSceneSwitchers || [];
    mics = data.mics || [];
    bitratePresets = (data.bitratePresets || []).map((p) => ({
      ...p,
      label: p.bitrate > 0 ? formatBytesPerSecond(p.bitrate) : "Unknown",
    }));
    if (data.srt && data.srt.connectionPriorities && data.srt.connectionPriorities.length > 0) {
      srtVisible = true;
      srtEnabled = data.srt.connectionPrioritiesEnabled;
      srtPriorities = data.srt.connectionPriorities.map((p) => ({ ...p }));
    }
    if (data.gimbalPresets && data.gimbalPresets.length > 0) {
      gimbalVisible = true;
      gimbalPresets = data.gimbalPresets;
    }
    filtersVisible = true;
  }

  function updateFilterStates(filters) {
    const next = { ...filterStates };
    for (let i = 0; i < filters.length; i += 2) {
      const name = Object.keys(filters[i])[0];
      next[name] = filters[i + 1];
    }
    filterStates = next;
  }

  // --- WebSocket connection ---
  class Connection extends WebSocketConnection {
    constructor() {
      super();
      this.statusTimerId = undefined;
    }

    onStatusChanged(s) {
      connStatus = s;
    }

    onConnected() {
      this.sendStartStatusRequest();
      this.sendGetStatusRequest();
      this.sendGetSettingsRequest();
    }

    reconnectSoon() {
      if (this.statusTimerId != undefined) {
        clearTimeout(this.statusTimerId);
        this.statusTimerId = undefined;
      }
      super.reconnectSoon();
    }

    handleResponse(_id, result, data) {
      if (!result.ok) {
        console.log("Unsuccessful request: ", result);
        return;
      }
      if (!data) return;
      if (data.getStatus) {
        updateStatus(data.getStatus);
        this.statusTimerId = setTimeout(() => this.sendGetStatusRequest(), 1000);
      }
      if (data.getSettings) populateSettings(data.getSettings.data);
    }

    handleEvent(data) {
      if (data.state) {
        const d = data.state.data;
        if (d.streaming !== undefined) isLive = d.streaming;
        if (d.recording !== undefined) isRecording = d.recording;
        if (d.muted !== undefined) isMuted = d.muted;
        if (d.debugLogging !== undefined) isDebugLogging = d.debugLogging;
        if (d.zoom !== undefined) zoom = d.zoom;
        if (d.scene !== undefined) selectedSceneId = d.scene;
        if (d.mic !== undefined) selectedMicId = d.mic;
        if (d.bitrate !== undefined) selectedBitrateId = d.bitrate;
        if (d.zoomPreset !== undefined) selectedZoomPresetId = d.zoomPreset;
        if (d.zoomPresets !== undefined) zoomPresets = d.zoomPresets;
        if (d.autoSceneSwitcher !== undefined) {
          selectedAutoSceneSwitcherId = d.autoSceneSwitcher ? d.autoSceneSwitcher.id : "";
        }
        if (d.filters !== undefined) updateFilterStates(d.filters);
      } else if (data.log) {
        logEntries = [...logEntries, data.log.entry];
      }
    }
  }

  const connection = new Connection();

  function submitZoom() {
    const val = parseFloat(zoom);
    if (!isNaN(val)) connection.setZoom(val);
  }

  function handleSrtSliderInput(e, priority) {
    // Update local display only
    srtPriorities = srtPriorities.map((p) =>
      p.id === priority.id ? { ...p, _displayPriority: parseInt(e.target.value) } : p,
    );
  }

  function handleSrtSliderChange(e, priority) {
    const value = parseInt(e.target.value);
    const updated = srtPriorities.map((p) =>
      p.id === priority.id ? { ...p, priority: value, _displayPriority: value } : p,
    );
    srtPriorities = updated;
    const p = updated.find((p) => p.id === priority.id);
    connection.setSrtConnectionPriority(priority.id, value, p.enabled);
  }

  function handleSrtCheckboxChange(e, priority) {
    const enabled = e.target.checked;
    srtPriorities = srtPriorities.map((p) =>
      p.id === priority.id ? { ...p, enabled } : p,
    );
    connection.setSrtConnectionPriority(priority.id, priority.priority, enabled);
  }
</script>

<div class="bg-zinc-950 text-zinc-100 font-sans p-2">
  <div class="max-w-3xl mx-auto space-y-2">
    <h1 class="text-2xl font-bold text-center">Moblin Remote Control</h1>

    <div class="text-center space-x-4">
      <a href="./remote.html" class="text-indigo-400 hover:text-indigo-300 text-sm"
        >Scoreboard Control</a
      >
      <a href="./scoreboard.html" class="text-indigo-400 hover:text-indigo-300 text-sm"
        >Scoreboard Display</a
      >
      <a href="./golf.html" class="text-indigo-400 hover:text-indigo-300 text-sm"
        >Golf Scoreboard</a
      >
      <a href="./recordings.html" class="text-indigo-400 hover:text-indigo-300 text-sm"
        >Recordings</a
      >
      <a
        href="https://github.com/eerimoq/moblin"
        target="_blank"
        class="text-indigo-400 hover:text-indigo-300 text-sm"
      >
        Github
      </a>
    </div>

    <div class="pb-1 text-center">
      {#if connStatus === connectionStatus.connecting}
        <span class="text-sm text-yellow-400">Connecting to server</span>
      {:else if connStatus === connectionStatus.connected}
        <span class="text-sm text-green-500">Connected to server</span>
      {:else}
        <span class="text-sm text-red-500">Unknown server status</span>
      {/if}
    </div>

    <!-- Status -->
    <div class="bg-zinc-900 border border-zinc-700 rounded-lg p-2">
      <h2 class="text-xl font-semibold mb-3">Status</h2>
      <h3 class="text-base font-medium text-zinc-300 mb-1">General</h3>
      <div class="overflow-x-auto">
        <table class="w-full text-sm text-left text-zinc-300 table-auto">
          <tbody>
            {#each statusGeneral as row}
              <tr class="border-b border-zinc-800">
                <td class="py-1.5 pr-4 text-zinc-200 font-medium whitespace-nowrap">{row.name}</td>
                <td class="py-1.5 text-zinc-200">{row.value}</td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
      <h3 class="text-base font-medium text-zinc-300 mt-3 mb-1">Top left</h3>
      <div class="overflow-x-auto">
        <table class="w-full text-sm text-left text-zinc-300 table-auto">
          <tbody>
            {#each statusTopLeft as row}
              <tr class="border-b border-zinc-800">
                <td class="py-1.5 pr-4 text-zinc-200 font-medium whitespace-nowrap">{row.name}</td>
                <td class="py-1.5 text-zinc-200">{row.value}</td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
      <h3 class="text-base font-medium text-zinc-300 mt-3 mb-1">Top right</h3>
      <div class="overflow-x-auto">
        <table class="w-full text-sm text-left text-zinc-300 table-auto">
          <tbody>
            {#each statusTopRight as row}
              <tr class="border-b border-zinc-800">
                <td class="py-1.5 pr-4 text-zinc-200 font-medium whitespace-nowrap">{row.name}</td>
                <td class="py-1.5 text-zinc-200">{row.value}</td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
    </div>

    <!-- Control -->
    <div class="bg-zinc-900 border border-zinc-700 rounded-lg p-2">
      <h2 class="text-xl font-semibold mb-3">Control</h2>
      {#if controlsVisible}
        <div class="space-y-3">
          <!-- Live -->
          <label class="flex items-center cursor-pointer">
            <div class="relative flex items-center">
              <input
                type="checkbox"
                class="peer appearance-none w-11 h-5 bg-slate-400 rounded-full checked:bg-indigo-800 cursor-pointer transition-colors duration-300"
                role="switch"
                checked={isLive}
                onchange={(e) => {
                  isLive = e.target.checked;
                  connection.setLive(e.target.checked);
                }}
              />
              <label
                class="absolute top-0 left-0 w-5 h-5 bg-white rounded-full border border-indigo-300 shadow-sm transition-transform duration-300 peer-checked:translate-x-6 peer-checked:border-slate-800 cursor-pointer"
              ></label>
              <span class="ml-3 text-sm text-zinc-200">Live</span>
            </div>
          </label>

          <!-- Recording -->
          <label class="flex items-center cursor-pointer">
            <div class="relative flex items-center">
              <input
                type="checkbox"
                class="peer appearance-none w-11 h-5 bg-slate-400 rounded-full checked:bg-indigo-800 cursor-pointer transition-colors duration-300"
                role="switch"
                checked={isRecording}
                onchange={(e) => {
                  isRecording = e.target.checked;
                  connection.setRecording(e.target.checked);
                }}
              />
              <label
                class="absolute top-0 left-0 w-5 h-5 bg-white rounded-full border border-indigo-300 shadow-sm transition-transform duration-300 peer-checked:translate-x-6 peer-checked:border-slate-800 cursor-pointer"
              ></label>
              <span class="ml-3 text-sm text-zinc-200">Recording</span>
            </div>
          </label>

          <!-- Muted -->
          <label class="flex items-center cursor-pointer">
            <div class="relative flex items-center">
              <input
                type="checkbox"
                class="peer appearance-none w-11 h-5 bg-slate-400 rounded-full checked:bg-indigo-800 cursor-pointer transition-colors duration-300"
                role="switch"
                checked={isMuted}
                onchange={(e) => {
                  isMuted = e.target.checked;
                  connection.setMuted(e.target.checked);
                }}
              />
              <label
                class="absolute top-0 left-0 w-5 h-5 bg-white rounded-full border border-indigo-300 shadow-sm transition-transform duration-300 peer-checked:translate-x-6 peer-checked:border-slate-800 cursor-pointer"
              ></label>
              <span class="ml-3 text-sm text-zinc-200">Muted</span>
            </div>
          </label>

          <!-- Zoom -->
          <div class="flex items-center space-x-4">
            <label class="text-sm text-zinc-200 w-24 shrink-0">Zoom</label>
            <input
              type="text"
              class="bg-zinc-800 border border-zinc-600 rounded px-2 py-1 text-sm text-zinc-200 w-20"
              placeholder="1.0"
              value={zoom}
              oninput={(e) => (zoom = e.target.value)}
              onkeydown={(e) => {
                if (e.key === "Enter") submitZoom();
              }}
              onblur={submitZoom}
            />
          </div>

          <!-- Zoom presets -->
          {#if zoomPresets.length > 0}
            <div class="flex flex-wrap gap-2">
              {#each zoomPresets as preset (preset.id)}
                <button
                  class={preset.id === selectedZoomPresetId
                    ? "bg-indigo-700 text-white text-sm px-3 py-1 rounded transition-colors"
                    : "bg-zinc-700 hover:bg-zinc-600 text-zinc-200 text-sm px-3 py-1 rounded transition-colors"}
                  onclick={() => {
                    selectedZoomPresetId = preset.id;
                    connection.setZoomPreset(preset.id);
                  }}
                >
                  {preset.name}
                </button>
              {/each}
            </div>
          {/if}

          <!-- Scene -->
          <div class="flex items-center space-x-4">
            <label class="text-sm text-zinc-200 w-24 shrink-0">Scene</label>
            <select
              class="bg-zinc-800 border border-zinc-600 rounded px-2 py-1 text-sm text-zinc-200 flex-1"
              value={selectedSceneId}
              onchange={(e) => {
                selectedSceneId = e.target.value;
                connection.setScene(e.target.value);
              }}
            >
              {#each scenes as scene (scene.id)}
                <option value={scene.id}>{scene.name}</option>
              {/each}
            </select>
          </div>

          <!-- Auto scene switcher -->
          <div class="flex items-center space-x-4">
            <label class="text-sm text-zinc-200 w-24 shrink-0">Auto scene</label>
            <select
              class="bg-zinc-800 border border-zinc-600 rounded px-2 py-1 text-sm text-zinc-200 flex-1"
              value={selectedAutoSceneSwitcherId}
              onchange={(e) => {
                selectedAutoSceneSwitcherId = e.target.value;
                connection.setAutoSceneSwitcher(e.target.value === "" ? null : e.target.value);
              }}
            >
              <option value="">-- None --</option>
              {#each autoSceneSwitchers as switcher (switcher.id)}
                <option value={switcher.id}>{switcher.name}</option>
              {/each}
            </select>
          </div>

          <!-- Mic -->
          <div class="flex items-center space-x-4">
            <label class="text-sm text-zinc-200 w-24 shrink-0">Mic</label>
            <select
              class="bg-zinc-800 border border-zinc-600 rounded px-2 py-1 text-sm text-zinc-200 flex-1"
              value={selectedMicId}
              onchange={(e) => {
                selectedMicId = e.target.value;
                connection.setMic(e.target.value);
              }}
            >
              {#each mics as mic (mic.id)}
                <option value={mic.id}>{mic.name}</option>
              {/each}
            </select>
          </div>

          <!-- Bitrate -->
          <div class="flex items-center space-x-4">
            <label class="text-sm text-zinc-200 w-24 shrink-0">Bitrate</label>
            <select
              class="bg-zinc-800 border border-zinc-600 rounded px-2 py-1 text-sm text-zinc-200 flex-1"
              value={selectedBitrateId}
              onchange={(e) => {
                selectedBitrateId = e.target.value;
                connection.setBitratePreset(e.target.value);
              }}
            >
              {#each bitratePresets as preset (preset.id)}
                <option value={preset.id}>{preset.label}</option>
              {/each}
            </select>
          </div>

          <!-- Debug logging -->
          <label class="flex items-center cursor-pointer">
            <div class="relative flex items-center">
              <input
                type="checkbox"
                class="peer appearance-none w-11 h-5 bg-slate-400 rounded-full checked:bg-indigo-800 cursor-pointer transition-colors duration-300"
                role="switch"
                checked={isDebugLogging}
                onchange={(e) => {
                  isDebugLogging = e.target.checked;
                  connection.setDebugLogging(e.target.checked);
                }}
              />
              <label
                class="absolute top-0 left-0 w-5 h-5 bg-white rounded-full border border-indigo-300 shadow-sm transition-transform duration-300 peer-checked:translate-x-6 peer-checked:border-slate-800 cursor-pointer"
              ></label>
              <span class="ml-3 text-sm text-zinc-200">Debug logging</span>
            </div>
          </label>

          <div class="flex flex-wrap gap-2">
            <button
              class="bg-zinc-700 hover:bg-zinc-600 text-zinc-200 text-sm px-3 py-1 rounded transition-colors"
              onclick={() => connection.reloadBrowserWidgets()}
            >
              Reload browser widgets
            </button>
          </div>
        </div>
      {/if}
    </div>

    <!-- SRT Connection Priorities -->
    {#if srtVisible}
      <div class="bg-zinc-900 border border-zinc-700 rounded-lg p-2">
        <h2 class="text-xl font-semibold mb-3">SRT Connection Priorities</h2>
        <label class="flex items-center cursor-pointer mb-3">
          <div class="relative flex items-center">
            <input
              type="checkbox"
              class="peer appearance-none w-11 h-5 bg-slate-400 rounded-full checked:bg-indigo-800 cursor-pointer transition-colors duration-300"
              role="switch"
              checked={srtEnabled}
              onchange={(e) => {
                srtEnabled = e.target.checked;
                connection.setSrtConnectionPrioritiesEnabled(e.target.checked);
              }}
            />
            <label
              class="absolute top-0 left-0 w-5 h-5 bg-white rounded-full border border-indigo-300 shadow-sm transition-transform duration-300 peer-checked:translate-x-6 peer-checked:border-slate-800 cursor-pointer"
            ></label>
            <span class="ml-3 text-sm text-zinc-200">Enabled</span>
          </div>
        </label>
        <div class="space-y-2">
          {#each srtPriorities as priority (priority.id)}
            {@const displayPriority = priority._displayPriority ?? priority.priority}
            <div class="flex items-center space-x-3">
              <label class="text-sm text-zinc-200 w-24 shrink-0">{priority.name}</label>
              <input
                type="checkbox"
                class="w-4 h-4 bg-zinc-800 border border-zinc-600 rounded cursor-pointer accent-indigo-600"
                checked={priority.enabled}
                onchange={(e) => handleSrtCheckboxChange(e, priority)}
              />
              <input
                type="range"
                min="0"
                max="9"
                value={displayPriority}
                class="flex-1 accent-indigo-600"
                oninput={(e) => handleSrtSliderInput(e, priority)}
                onchange={(e) => handleSrtSliderChange(e, priority)}
              />
              <span class="text-sm text-zinc-300 w-6 text-right">{displayPriority}</span>
            </div>
          {/each}
        </div>
      </div>
    {/if}

    <!-- Gimbal Presets -->
    {#if gimbalVisible}
      <div class="bg-zinc-900 border border-zinc-700 rounded-lg p-2">
        <h2 class="text-xl font-semibold mb-3">Gimbal Presets</h2>
        <div class="flex flex-wrap gap-2">
          {#each gimbalPresets as preset (preset.id)}
            <button
              class="bg-zinc-700 hover:bg-zinc-600 text-zinc-200 text-sm px-4 py-2 rounded transition-colors"
              onclick={() => connection.moveToGimbalPreset(preset.id)}
            >
              {preset.name}
            </button>
          {/each}
        </div>
      </div>
    {/if}

    <!-- Filters -->
    {#if filtersVisible}
      <div class="bg-zinc-900 border border-zinc-700 rounded-lg p-2">
        <h2 class="text-xl font-semibold mb-3">Filters</h2>
        <div class="space-y-3">
          {#each allFilterKeys as key}
            <label class="flex items-center cursor-pointer">
              <div class="relative flex items-center">
                <input
                  type="checkbox"
                  class="peer appearance-none w-11 h-5 bg-slate-400 rounded-full checked:bg-indigo-800 cursor-pointer transition-colors duration-300"
                  role="switch"
                  checked={filterStates[key] || false}
                  onchange={(e) => {
                    filterStates = { ...filterStates, [key]: e.target.checked };
                    connection.setFilter(key, e.target.checked);
                  }}
                />
                <label
                  class="absolute top-0 left-0 w-5 h-5 bg-white rounded-full border border-indigo-300 shadow-sm transition-transform duration-300 peer-checked:translate-x-6 peer-checked:border-slate-800 cursor-pointer"
                ></label>
                <span class="ml-3 text-sm text-zinc-200">{filterNames[key] || key}</span>
              </div>
            </label>
          {/each}
        </div>
      </div>
    {/if}

    <!-- Log -->
    <div class="bg-zinc-900 border border-zinc-700 rounded-lg p-2">
      <h2 class="text-xl font-semibold mb-3">Log</h2>
      <div class="overflow-y-auto h-96 text-sm text-zinc-300">
        {#each logEntries as entry}
          <div>{entry}</div>
        {/each}
      </div>
    </div>
  </div>
</div>
