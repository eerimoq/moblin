import { createSignal, For, Show } from "solid-js";
import type { Accessor } from "solid-js";
import { createStore } from "solid-js/store";
import { render } from "solid-js/web";
import {
  BitratePreset,
  connectionStatus,
  convertFilters,
  EventData,
  GimbalPreset,
  NamedItem,
  RemoteControlAssistantStreamerState,
  RemoteControlResponseGetStatus,
  RemoteControlSettings,
  RemoteControlSettingsSrtConnectionPriority,
  RemoteControlStatusGeneral,
  RemoteControlStatusTopLeft,
  RemoteControlStatusTopRight,
  ResponseData,
  SrtPriority,
  WebSocketConnection,
  ZoomPreset,
} from "./utils.ts";
import {
  GitHubLink,
  Button,
  ConfirmDialog,
  Picker,
  Section,
  Toggle,
  Title,
  ConnectingOverlay,
} from "./components.tsx";

type StatusRow = [string, string];

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

function formatBytesPerSecond(bps: number): string {
  if (bps >= 1000000) return (bps / 1000000).toFixed(1) + " Mbps";
  if (bps >= 1000) return (bps / 1000).toFixed(0) + " Kbps";
  return bps + " bps";
}

interface StatusTableProps {
  rows: Accessor<StatusRow[]>;
}

function StatusTable({ rows }: StatusTableProps) {
  return (
    <div class="overflow-x-auto">
      <table class="w-full text-sm text-left text-zinc-300 table-auto">
        <tbody>
          <For each={rows()}>
            {([name, value]) => (
              <tr class="border-b border-zinc-800">
                <td class="py-1.5 pr-4 text-zinc-200 font-medium whitespace-nowrap">{name}</td>
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
  const [status, setStatus] = createSignal<string>(connectionStatus.connecting);
  const [generalRows, setGeneralRows] = createSignal<StatusRow[]>([]);
  const [topLeftRows, setTopLeftRows] = createSignal<StatusRow[]>([]);
  const [topRightRows, setTopRightRows] = createSignal<StatusRow[]>([]);
  const [showControl, setShowControl] = createSignal(false);
  const [showSrt, setShowSrt] = createSignal(false);
  const [showGimbal, setShowGimbal] = createSignal(false);
  const [showFilters, setShowFilters] = createSignal(false);
  const [liveOn, setLiveOn] = createSignal(false);
  const [recordingOn, setRecordingOn] = createSignal(false);
  const [mutedOn, setMutedOn] = createSignal(false);
  const [previewStreamOn, setPreviewStreamOn] = createSignal(false);
  const [pendingLive, setPendingLive] = createSignal<boolean | null>(null);
  const [pendingRecording, setPendingRecording] = createSignal<boolean | null>(null);
  const [pendingPreviewStream, setPendingPreviewStream] = createSignal<boolean | null>(null);
  const [debugLoggingOn, setDebugLoggingOn] = createSignal(false);
  const [zoomValue, setZoomValue] = createSignal("");
  const [zoomPresets, setZoomPresets] = createSignal<ZoomPreset[]>([]);
  const [currentZoomPresetId, setCurrentZoomPresetId] = createSignal<string | null>(null);
  const [scenes, setScenes] = createSignal<NamedItem[]>([]);
  const [currentSceneId, setCurrentSceneId] = createSignal("");
  const [autoSwitchers, setAutoSwitchers] = createSignal<NamedItem[]>([]);
  const [currentAutoSwitcherId, setCurrentAutoSwitcherId] = createSignal("");
  const [mics, setMics] = createSignal<NamedItem[]>([]);
  const [currentMicId, setCurrentMicId] = createSignal("");
  const [bitratePresets, setBitratePresets] = createSignal<BitratePreset[]>([]);
  const [currentBitrateId, setCurrentBitrateId] = createSignal("");
  const [srtEnabled, setSrtEnabled] = createSignal(false);
  const [srtPriorities, setSrtPriorities] = createStore<
    RemoteControlSettingsSrtConnectionPriority[]
  >([]);
  const [gimbalPresets, setGimbalPresets] = createSignal<GimbalPreset[]>([]);
  const [filterStates, setFilterStates] = createStore<Record<string, boolean>>({});
  let logContainer: HTMLDivElement | undefined;

  class IndexConnection extends WebSocketConnection {
    statusTimerId: ReturnType<typeof setTimeout> | undefined;
    settingsTimerId: ReturnType<typeof setTimeout> | undefined;

    constructor() {
      super();
      this.statusTimerId = undefined;
      this.settingsTimerId = undefined;
    }

    onStatusChanged(newStatus: string): void {
      setStatus(newStatus);
    }

    onConnected(): void {
      this.sendStartStatusRequest();
      this.sendGetStatusRequest();
      this.sendGetSettingsRequest();
    }

    reconnectSoon(): void {
      if (this.statusTimerId !== undefined) {
        clearTimeout(this.statusTimerId);
        this.statusTimerId = undefined;
      }
      if (this.settingsTimerId !== undefined) {
        clearTimeout(this.settingsTimerId);
        this.settingsTimerId = undefined;
      }
      super.reconnectSoon();
    }

    handleResponse(_id: number, result: { ok: boolean }, data?: ResponseData): void {
      if (!result.ok || data === undefined) return;
      if (data.getStatus !== undefined) {
        this.handleGetStatusResponse(data.getStatus);
      } else if (data.getSettings !== undefined) {
        this.handleGetSettingsResponse(data.getSettings.data);
      }
    }

    handleGetStatusResponse(status: RemoteControlResponseGetStatus): void {
      updateStatus(status);
      this.statusTimerId = setTimeout(() => {
        this.sendGetStatusRequest();
      }, 1000);
    }

    handleGetSettingsResponse(settings: RemoteControlSettings): void {
      populateSettings(settings);
      this.settingsTimerId = setTimeout(() => {
        this.sendGetSettingsRequest();
      }, 10000);
    }

    handleEvent(data: EventData): void {
      if (data.state !== undefined) {
        this.handleStateEvent(data.state.data);
      } else if (data.log !== undefined) {
        const entry = document.createElement("div");
        entry.textContent = data.log.entry;
        if (logContainer) logContainer.appendChild(entry);
      }
    }

    handleStateEvent(state: RemoteControlAssistantStreamerState): void {
      if (state.streaming !== undefined) {
        setLiveOn(state.streaming);
      }
      if (state.recording !== undefined) {
        setRecordingOn(state.recording);
      }
      if (state.muted !== undefined) {
        setMutedOn(state.muted);
      }
      if (state.previewStream !== undefined) {
        setPreviewStreamOn(state.previewStream);
      }
      if (state.debugLogging !== undefined) {
        setDebugLoggingOn(state.debugLogging);
      }
      if (state.zoom !== undefined) {
        setZoomValue(String(state.zoom));
      }
      if (state.scene !== undefined) {
        setCurrentSceneId(state.scene);
      }
      if (state.mic !== undefined) {
        setCurrentMicId(state.mic);
      }
      if (state.bitrate !== undefined) {
        setCurrentBitrateId(state.bitrate);
      }
      if (state.zoomPreset !== undefined) {
        setCurrentZoomPresetId(state.zoomPreset);
      }
      if (state.zoomPresets !== undefined) {
        setZoomPresets(state.zoomPresets);
        setCurrentZoomPresetId(state.zoomPreset ?? null);
      }
      if (state.autoSceneSwitcher !== undefined) {
        setCurrentAutoSwitcherId(state.autoSceneSwitcher.id ?? "");
      }
      if (state.filters !== undefined) {
        for (const [name, on] of convertFilters(state.filters)) {
          setFilterStates(name, on);
        }
      }
    }
  }

  const connection = new IndexConnection();

  function updateStatus(status: RemoteControlResponseGetStatus): void {
    updateStatusGeneral(status.general);
    updateStatusTopLeft(status.topLeft);
    updateStatusTopRight(status.topRight);
  }

  function updateStatusGeneral(general?: RemoteControlStatusGeneral): void {
    if (general === undefined) {
      return;
    }
    let rows: StatusRow[] = [];
    if (general.batteryLevel !== undefined) {
      rows.push(["Battery level", `${general.batteryLevel}%`]);
    }
    if (general.isMuted !== undefined) {
      rows.push(["Muted", general.isMuted ? "Yes" : "No"]);
    }
    if (general.flame !== undefined) {
      rows.push(["Flame", general.flame]);
    }
    if (general.wiFiSsid !== undefined) {
      rows.push(["WiFi", general.wiFiSsid]);
    }
    setGeneralRows(rows);
  }

  function updateStatusTopLeft(topLeft: RemoteControlStatusTopLeft): void {
    let rows: StatusRow[] = [];
    if (topLeft.stream !== undefined) {
      rows.push(["Stream", topLeft.stream.message]);
    }
    if (topLeft.camera !== undefined) {
      rows.push(["Camera", topLeft.camera.message]);
    }
    if (topLeft.mic !== undefined) {
      rows.push(["Mic", topLeft.mic.message]);
    }
    if (topLeft.zoom !== undefined) {
      rows.push(["Zoom", topLeft.zoom.message]);
    }
    if (topLeft.obs !== undefined) {
      rows.push(["OBS", topLeft.obs.message]);
    }
    if (topLeft.events !== undefined) {
      rows.push(["Events", topLeft.events.message]);
    }
    if (topLeft.chat !== undefined) {
      rows.push(["Chat", topLeft.chat.message]);
    }
    if (topLeft.viewers !== undefined) {
      rows.push(["Viewers", topLeft.viewers.message]);
    }
    setTopLeftRows(rows);
  }

  function updateStatusTopRight(topRight: RemoteControlStatusTopRight): void {
    let rows: StatusRow[] = [];
    if (topRight.audioLevel !== undefined) {
      rows.push(["Audio", topRight.audioLevel.message]);
    }
    if (topRight.rtmpServer !== undefined) {
      rows.push(["Ingests", topRight.rtmpServer.message]);
    }
    if (topRight.remoteControl !== undefined) {
      rows.push(["Remote control", topRight.remoteControl.message]);
    }
    if (topRight.gameController !== undefined) {
      rows.push(["Game controller", topRight.gameController.message]);
    }
    if (topRight.bitrate !== undefined) {
      rows.push(["Bitrate", topRight.bitrate.message]);
    }
    if (topRight.uptime !== undefined) {
      rows.push(["Uptime", topRight.uptime.message]);
    }
    if (topRight.location !== undefined) {
      rows.push(["Location", topRight.location.message]);
    }
    if (topRight.srtla !== undefined) {
      rows.push(["Bonding", topRight.srtla.message]);
    }
    if (topRight.srtlaRtts !== undefined) {
      rows.push(["Bonding RTT:s", topRight.srtlaRtts.message]);
    }
    if (topRight.recording !== undefined) {
      rows.push(["Recording", topRight.recording.message]);
    }
    if (topRight.replay !== undefined) {
      rows.push(["Replay", topRight.replay.message]);
    }
    if (topRight.browserWidgets !== undefined) {
      rows.push(["Browser widgets", topRight.browserWidgets.message]);
    }
    if (topRight.moblink !== undefined) {
      rows.push(["Moblink", topRight.moblink.message]);
    }
    if (topRight.djiDevices !== undefined) {
      rows.push(["DJI devices", topRight.djiDevices.message]);
    }
    if (topRight.systemMonitor !== undefined) {
      rows.push(["System monitor", topRight.systemMonitor.message]);
    }
    setTopRightRows(rows);
  }

  function populateSettings(data: RemoteControlSettings): void {
    setShowControl(true);
    setScenes(data.scenes);
    let baseAutoSceneSwitchers: NamedItem[] = [{ id: "", name: "-- None --" }];
    setAutoSwitchers(baseAutoSceneSwitchers.concat(data.autoSceneSwitchers ?? []));
    setMics(data.mics);
    setBitratePresets(data.bitratePresets);
    if (data.srt.connectionPriorities.length > 0) {
      setShowSrt(true);
      setSrtEnabled(data.srt.connectionPrioritiesEnabled);
      setSrtPriorities(data.srt.connectionPriorities);
    } else {
      setShowSrt(false);
    }
    if (data.gimbalPresets.length > 0) {
      setShowGimbal(true);
      setGimbalPresets(data.gimbalPresets);
    } else {
      setShowGimbal(false);
    }
    setShowFilters(true);
  }

  function handleZoomSubmit() {
    const value = parseFloat(zoomValue());
    if (!isNaN(value)) connection.setZoom(value);
  }

  function Links() {
    return (
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
        <GitHubLink />
      </div>
    );
  }

  function Status() {
    return (
      <Section title="Status">
        <h3 class="text-base font-medium text-zinc-300 mb-1">General</h3>
        <StatusTable rows={generalRows} />
        <h3 class="text-base font-medium text-zinc-300 mt-3 mb-1">Top left</h3>
        <StatusTable rows={topLeftRows} />
        <h3 class="text-base font-medium text-zinc-300 mt-3 mb-1">Top right</h3>
        <StatusTable rows={topRightRows} />
      </Section>
    );
  }

  function Control() {
    return (
      <Section title="Control">
        <Show when={showControl()}>
          <div class="space-y-3">
            <Toggle
              id="controlLive"
              checked={pendingLive() !== null ? pendingLive()! : liveOn()}
              onChange={(event) => setPendingLive(event.target.checked)}
              label="Live"
            />
            <ConfirmDialog
              open={() => pendingLive() !== null}
              message={() => (pendingLive() ? "Go live?" : "End?")}
              onOk={() => {
                const value = pendingLive();
                setPendingLive(null);
                if (value !== null) connection.setLive(value);
              }}
              onCancel={() => setPendingLive(null)}
              okTextClass="text-zinc-300"
            />
            <Toggle
              id="controlRecording"
              checked={pendingRecording() !== null ? pendingRecording()! : recordingOn()}
              onChange={(event) => setPendingRecording(event.target.checked)}
              label="Recording"
            />
            <ConfirmDialog
              open={() => pendingRecording() !== null}
              message={() => (pendingRecording() ? "Start recording?" : "Stop recording?")}
              onOk={() => {
                const value = pendingRecording();
                setPendingRecording(null);
                if (value !== null) connection.setRecording(value);
              }}
              onCancel={() => setPendingRecording(null)}
              okTextClass="text-zinc-300"
            />
            <Toggle
              id="controlMuted"
              checked={mutedOn()}
              onChange={(event) => connection.setMuted(event.target.checked)}
              label="Muted"
            />
            <Toggle
              id="controlPreviewStream"
              checked={
                pendingPreviewStream() !== null ? pendingPreviewStream()! : previewStreamOn()
              }
              onChange={(event) => setPendingPreviewStream(event.target.checked)}
              label="Preview stream"
            />
            <ConfirmDialog
              open={() => pendingPreviewStream() !== null}
              message={() =>
                pendingPreviewStream() ? "Start preview stream?" : "Stop preview stream?"
              }
              onOk={() => {
                const value = pendingPreviewStream();
                setPendingPreviewStream(null);
                if (value !== null) connection.setPreviewStream(value);
              }}
              onCancel={() => setPendingPreviewStream(null)}
              okTextClass="text-zinc-300"
            />
            <div class="flex items-center space-x-4">
              <label class="text-sm text-zinc-200 w-24 shrink-0">Zoom</label>
              <input
                type="text"
                class="bg-zinc-800 border border-zinc-600 rounded px-2 py-1 text-sm text-zinc-200 w-20"
                placeholder="1.0"
                value={zoomValue()}
                onInput={(event) => setZoomValue(event.target.value)}
                onKeyDown={(event) => {
                  if (event.key === "Enter") handleZoomSubmit();
                }}
                onBlur={handleZoomSubmit}
              />
            </div>
            <Show when={zoomPresets().length > 0}>
              <div class="flex flex-wrap gap-2">
                <For each={zoomPresets()}>
                  {(preset) => (
                    <Button
                      class={
                        preset.id === currentZoomPresetId()
                          ? "bg-indigo-700 text-white"
                          : "bg-zinc-700 hover:bg-zinc-600 text-zinc-200"
                      }
                      onClick={() => connection.setZoomPreset(preset.id)}
                    >
                      {preset.name}
                    </Button>
                  )}
                </For>
              </div>
            </Show>
            <Picker
              name="Scene"
              options={scenes}
              value={currentSceneId}
              onChange={(value) => connection.setScene(value)}
            />
            <Picker
              name="Auto scene switcher"
              options={autoSwitchers}
              value={currentAutoSwitcherId}
              onChange={(value) => {
                connection.setAutoSceneSwitcher(value === "" ? null : value);
              }}
            />
            <Picker
              name="Mic"
              options={mics}
              value={currentMicId}
              onChange={(value) => connection.setMic(value)}
            />
            <Picker
              name="Bitrate"
              options={(): NamedItem[] => {
                return bitratePresets().map(({ id, bitrate }): NamedItem => {
                  return { id, name: bitrate > 0 ? formatBytesPerSecond(bitrate) : "Unknown" };
                });
              }}
              value={currentBitrateId}
              onChange={(value) => connection.setBitratePreset(value)}
            />
            <Toggle
              id="controlDebugLogging"
              checked={debugLoggingOn()}
              onChange={(event) => connection.setDebugLogging(event.target.checked)}
              label="Debug logging"
            />
            <div class="flex flex-wrap gap-2">
              <Button
                class="bg-zinc-700 hover:bg-zinc-600 text-zinc-200"
                onClick={() => connection.reloadBrowserWidgets()}
              >
                Reload browser widgets
              </Button>
            </div>
          </div>
        </Show>
      </Section>
    );
  }

  function SrtConnectionPriorities() {
    return (
      <Show when={showSrt()}>
        <Section title="SRT Connection Priorities">
          <Toggle
            id="controlSrtEnabled"
            checked={srtEnabled()}
            onChange={(event) => {
              setSrtEnabled(event.target.checked);
              connection.setSrtConnectionPrioritiesEnabled(event.target.checked);
            }}
            label="Enabled"
          />
          <div class="space-y-2 mt-3">
            <For each={srtPriorities}>
              {(priority, priorityIndex) => (
                <SrtPriorityRow
                  priority={priority}
                  onChange={(priorityValue, enabled) => {
                    setSrtPriorities(priorityIndex(), "priority", priorityValue);
                    setSrtPriorities(priorityIndex(), "enabled", enabled);
                    connection.setSrtConnectionPriority(priority.id, priorityValue, enabled);
                  }}
                />
              )}
            </For>
          </div>
        </Section>
      </Show>
    );
  }

  function GimbalPresets() {
    return (
      <Show when={showGimbal()}>
        <Section title="Gimbal Presets">
          <div class="flex flex-wrap gap-2">
            <For each={gimbalPresets()}>
              {(preset) => (
                <Button
                  class="bg-zinc-700 hover:bg-zinc-600 text-zinc-200 px-4 py-2"
                  onClick={() => connection.moveToGimbalPreset(preset.id)}
                >
                  {preset.name}
                </Button>
              )}
            </For>
          </div>
        </Section>
      </Show>
    );
  }

  function Filters() {
    return (
      <Show when={showFilters()}>
        <Section title="Filters">
          <div class="space-y-3">
            <For each={allFilterKeys}>
              {(key) => (
                <Toggle
                  id={`filter_${key}`}
                  checked={filterStates[key] || false}
                  onChange={(event) => {
                    setFilterStates(key, event.target.checked);
                    connection.setFilter(key, event.target.checked);
                  }}
                  label={filterNames[key as keyof typeof filterNames] || key}
                />
              )}
            </For>
          </div>
        </Section>
      </Show>
    );
  }

  function Log() {
    return (
      <Section title="Log">
        <div
          ref={(el: HTMLDivElement) => {
            logContainer = el;
          }}
          class="overflow-y-auto h-96 text-sm text-zinc-300"
        />
      </Section>
    );
  }

  return (
    <div class="max-w-3xl mx-auto space-y-2">
      <Title title="Moblin Remote Control" />
      <Links />
      <ConnectingOverlay status={status} />
      <Status />
      <Control />
      <SrtConnectionPriorities />
      <GimbalPresets />
      <Filters />
      <Log />
    </div>
  );
}

interface SrtPriorityRowProps {
  priority: SrtPriority;
  onChange: (priority: number, enabled: boolean) => void;
}

function SrtPriorityRow({ priority, onChange }: SrtPriorityRowProps) {
  const [sliderValue, setSliderValue] = createSignal(priority.priority);
  const [checked, setChecked] = createSignal(priority.enabled);

  return (
    <div class="flex items-center space-x-3">
      <label class="text-sm text-zinc-200 w-24 shrink-0">{priority.name}</label>
      <input
        type="checkbox"
        checked={checked()}
        class="w-4 h-4 bg-zinc-800 border border-zinc-600 rounded cursor-pointer accent-indigo-600"
        onChange={(event) => {
          setChecked(event.target.checked);
          onChange(sliderValue(), event.target.checked);
        }}
      />
      <input
        type="range"
        min="1"
        max="10"
        value={sliderValue()}
        class="flex-1 accent-indigo-600"
        onInput={(event) => setSliderValue(parseInt(event.target.value))}
        onChange={(event) => onChange(parseInt(event.target.value), checked())}
      />
      <span class="text-sm text-zinc-300 w-6 text-right">{sliderValue()}</span>
    </div>
  );
}

render(() => <App />, document.getElementById("app")!);
