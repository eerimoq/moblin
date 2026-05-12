import { createSignal, For, Show } from "solid-js";
import type { Accessor } from "solid-js";
import { createStore } from "solid-js/store";
import { render } from "solid-js/web";
import {
  BitratePreset,
  connectionStatus,
  GimbalPreset,
  NamedItem,
  SrtPriority,
  WebSocketConnection,
  ZoomPreset,
} from "./utils.ts";
import {
  GitHubLink,
  Button,
  Picker,
  Section,
  Toggle,
  Title,
  ConnectionStatus,
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
  const [srtPriorities, setSrtPriorities] = createStore<SrtPriority[]>([]);
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

    handleResponse(_id: number, result: { ok: boolean }, data: unknown): void {
      if (!result.ok) return;
      if (!data) return;
      const d = data as {
        getStatus?: Record<string, unknown>;
        getSettings?: { data: Record<string, unknown> };
      };
      if (d.getStatus) {
        this.handleGetStatusResponse(d.getStatus);
      }
      if (d.getSettings) {
        this.handleGetSettingsResponse(d.getSettings);
      }
    }

    handleGetStatusResponse(status: Record<string, unknown>): void {
      updateStatus(status);
      this.statusTimerId = setTimeout(() => {
        this.sendGetStatusRequest();
      }, 1000);
    }

    handleGetSettingsResponse(settingsData: { data: Record<string, unknown> }): void {
      populateSettings(settingsData.data);
      this.settingsTimerId = setTimeout(() => {
        this.sendGetSettingsRequest();
      }, 10000);
    }

    handleEvent(data: unknown): void {
      const d = data as {
        state?: { data: Record<string, unknown> };
        log?: { entry: string };
      };
      if (d.state) {
        this.handleStateEvent(d.state);
      } else if (d.log) {
        const entry = document.createElement("div");
        entry.textContent = d.log.entry;
        if (logContainer) logContainer.appendChild(entry);
      }
    }

    handleStateEvent(state: { data: Record<string, unknown> }): void {
      const sd = state.data;
      if (sd.streaming !== undefined) setLiveOn(sd.streaming as boolean);
      if (sd.recording !== undefined) setRecordingOn(sd.recording as boolean);
      if (sd.muted !== undefined) setMutedOn(sd.muted as boolean);
      if (sd.debugLogging !== undefined) setDebugLoggingOn(sd.debugLogging as boolean);
      if (sd.zoom !== undefined) setZoomValue(String(sd.zoom));
      if (sd.scene !== undefined) {
        setCurrentSceneId(sd.scene as string);
      }
      if (sd.mic !== undefined) {
        setCurrentMicId(sd.mic as string);
      }
      if (sd.bitrate !== undefined) {
        setCurrentBitrateId(sd.bitrate as string);
      }
      if (sd.zoomPreset !== undefined) {
        setCurrentZoomPresetId(sd.zoomPreset as string);
      }
      if (sd.zoomPresets !== undefined) {
        setZoomPresets(sd.zoomPresets as ZoomPreset[]);
        setCurrentZoomPresetId((sd.zoomPreset as string | undefined) ?? null);
      }
      if (sd.autoSceneSwitcher !== undefined) {
        const switcher = sd.autoSceneSwitcher as { id: string } | null;
        setCurrentAutoSwitcherId(switcher ? (switcher.id ?? "") : "");
      }
      if (sd.filters !== undefined) {
        const filters = sd.filters as unknown[];
        for (let filterIndex = 0; filterIndex < filters.length; filterIndex += 2) {
          const name = Object.keys(filters[filterIndex] as object)[0];
          const on = filters[filterIndex + 1] as boolean;
          setFilterStates(name, on);
        }
      }
    }
  }

  const connection = new IndexConnection();

  function overlayStatusRows(overlay: Record<string, { message: string }>): StatusRow[] {
    return Object.keys(overlay)
      .sort()
      .filter((key) => statusKeyToName[key as keyof typeof statusKeyToName])
      .map((key) => [statusKeyToName[key as keyof typeof statusKeyToName], overlay[key].message]);
  }

  function updateStatus(status: Record<string, unknown>): void {
    const general = status.general as {
      batteryLevel: number;
      isMuted: boolean;
      flame: string;
      wiFiSsid: string;
    };
    const genRows: StatusRow[] = [
      ["Battery level", String(general.batteryLevel)],
      ["Muted", String(general.isMuted)],
      ["Flame", general.flame],
      ["WiFi", general.wiFiSsid],
    ];
    setGeneralRows(genRows);
    const topLeft = (status.topLeft ?? {}) as Record<string, { message: string }>;
    setTopLeftRows(overlayStatusRows(topLeft));
    const topRight = (status.topRight ?? {}) as Record<string, { message: string }>;
    setTopRightRows(overlayStatusRows(topRight));
  }

  function populateSettings(data: Record<string, unknown>): void {
    setShowControl(true);
    setScenes((data.scenes as NamedItem[]) ?? []);
    let baseAutoSceneSwitchers: NamedItem[] = [{ id: "", name: "-- None --" }];
    setAutoSwitchers(baseAutoSceneSwitchers.concat(data.autoSceneSwitchers as NamedItem[]) ?? []);
    setMics((data.mics as NamedItem[]) ?? []);
    setBitratePresets((data.bitratePresets as BitratePreset[]) ?? []);
    const srt = data.srt as
      | {
          connectionPriorities: SrtPriority[];
          connectionPrioritiesEnabled: boolean;
        }
      | undefined;
    if (srt && srt.connectionPriorities && srt.connectionPriorities.length > 0) {
      setShowSrt(true);
      setSrtEnabled(srt.connectionPrioritiesEnabled);
      setSrtPriorities(srt.connectionPriorities);
    }
    const gimbalPresetList = data.gimbalPresets as GimbalPreset[] | undefined;
    if (gimbalPresetList && gimbalPresetList.length > 0) {
      setShowGimbal(true);
      setGimbalPresets(gimbalPresetList);
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
              checked={liveOn()}
              onChange={(event) => connection.setLive(event.target.checked)}
              label="Live"
            />
            <Toggle
              id="controlRecording"
              checked={recordingOn()}
              onChange={(event) => connection.setRecording(event.target.checked)}
              label="Recording"
            />
            <Toggle
              id="controlMuted"
              checked={mutedOn()}
              onChange={(event) => connection.setMuted(event.target.checked)}
              label="Muted"
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
      <ConnectionStatus status={status} />
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
