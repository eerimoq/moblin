import { batch, createSignal } from "solid-js";
import { createStore, reconcile } from "solid-js/store";
import {
  connectionStatus,
  convertFilters,
  createScoreboardTeam,
  EventData,
  GimbalPreset,
  RemoteControlAssistantStreamerState,
  RemoteControlGolfScoreboard,
  RemoteControlResponseGetStatus,
  RemoteControlSettings,
  RemoteControlSettingsSrtConnectionPriority,
  ResponseData,
  ScoreboardMatchConfig,
  WebSocketConnection,
  ZoomPreset,
} from "./utils.ts";

export interface StreamerState {
  streaming: boolean;
  recording: boolean;
  muted: boolean;
  stealthMode: boolean;
  previewStream: boolean;
  debugLogging: boolean;
  zoom: number | undefined;
  zoomPresets: ZoomPreset[];
  zoomPreset: string | null;
  scene: string;
  mic: string;
  bitrate: string;
  autoSceneSwitcher: string;
  filters: Record<string, boolean>;
  gimbalTracking: boolean;
  gimbalPresets: GimbalPreset[];
}

export interface ReconnectInfo {
  attempt: number;
  lostAt: number | undefined;
  nextRetryAt: number | undefined;
}

export const emptyGolf: RemoteControlGolfScoreboard = {
  title: "",
  numberOfHoles: 18,
  pars: [4, 4, 3, 4, 5, 4, 3, 4, 4, 4, 4, 3, 5, 4, 4, 3, 4, 5],
  currentHole: 0,
  players: [],
  playerColors: false,
};

function emptyScoreboard(): ScoreboardMatchConfig {
  return {
    sportId: "",
    layout: "",
    team1: createScoreboardTeam(),
    team2: createScoreboardTeam(),
    global: {
      title: "",
      period: "1",
      periodLabel: "",
      timer: "",
      timerDirection: "down",
      duration: "",
      infoBoxText: "",
      scoringMode: "normal",
      showTitle: false,
      showStats: false,
      showMoreStats: false,
      showClock: false,
      changePossessionOnScore: false,
    },
    controls: {},
  };
}

const maximumLogLines = 2000;

export function createRemote() {
  const [status, setStatus] = createSignal<string>(connectionStatus.connecting);
  const [everConnected, setEverConnected] = createSignal(false);
  const [reconnect, setReconnect] = createSignal<ReconnectInfo>({
    attempt: 0,
    lostAt: undefined,
    nextRetryAt: undefined,
  });
  const [state, setState] = createStore<StreamerState>({
    streaming: false,
    recording: false,
    muted: false,
    stealthMode: false,
    previewStream: false,
    debugLogging: false,
    zoom: undefined,
    zoomPresets: [],
    zoomPreset: null,
    scene: "",
    mic: "",
    bitrate: "",
    autoSceneSwitcher: "",
    filters: {},
    gimbalTracking: true,
    gimbalPresets: [],
  });
  const [statusData, setStatusData] = createSignal<RemoteControlResponseGetStatus | null>(null);
  const [settings, setSettings] = createSignal<RemoteControlSettings | null>(null);
  const [srtEnabled, setSrtEnabled] = createSignal(false);
  const [srtPriorities, setSrtPriorities] = createStore<
    RemoteControlSettingsSrtConnectionPriority[]
  >([]);
  const [log, setLog] = createSignal<string[]>([]);
  const [preview, setPreview] = createSignal<string | null>(null);
  const [scoreboard, setScoreboard] = createStore<ScoreboardMatchConfig>(emptyScoreboard());
  const [sports, setSports] = createSignal<string[]>([]);
  const [clockRunning, setClockRunning] = createSignal(false);
  const [golf, setGolf] = createStore<RemoteControlGolfScoreboard>(structuredClone(emptyGolf));
  let previewWanted = false;
  let clockTimerId: ReturnType<typeof setTimeout> | undefined;

  function applyState(update: RemoteControlAssistantStreamerState): void {
    batch(() => {
      if (update.streaming !== undefined) setState("streaming", update.streaming);
      if (update.recording !== undefined) setState("recording", update.recording);
      if (update.muted !== undefined) setState("muted", update.muted);
      if (update.stealthMode !== undefined) setState("stealthMode", update.stealthMode);
      if (update.previewStream !== undefined) setState("previewStream", update.previewStream);
      if (update.debugLogging !== undefined) setState("debugLogging", update.debugLogging);
      if (update.zoom !== undefined) setState("zoom", update.zoom);
      if (update.scene !== undefined) setState("scene", update.scene);
      if (update.mic !== undefined) setState("mic", update.mic);
      if (update.bitrate !== undefined) setState("bitrate", update.bitrate);
      if (update.zoomPreset !== undefined) setState("zoomPreset", update.zoomPreset);
      if (update.zoomPresets !== undefined) {
        setState("zoomPresets", update.zoomPresets);
        setState("zoomPreset", update.zoomPreset ?? null);
      }
      if (update.autoSceneSwitcher !== undefined) {
        setState("autoSceneSwitcher", update.autoSceneSwitcher.id ?? "");
      }
      if (update.filters !== undefined) {
        for (const [name, on] of convertFilters(update.filters)) {
          setState("filters", name, on);
        }
      }
      if (update.gimbalTracking !== undefined) setState("gimbalTracking", update.gimbalTracking);
      if (update.gimbalPresets !== undefined) setState("gimbalPresets", update.gimbalPresets);
    });
  }

  function applyScoreboard(config: ScoreboardMatchConfig): void {
    const previousTimer = scoreboard.global.timer;
    setScoreboard(reconcile(config));
    if (previousTimer !== "" && config.global.timer !== previousTimer) {
      setClockRunning(true);
      clearTimeout(clockTimerId);
      clockTimerId = setTimeout(() => setClockRunning(false), 1600);
    }
  }

  class RemoteConnection extends WebSocketConnection {
    statusTimerId: ReturnType<typeof setTimeout> | undefined;
    settingsTimerId: ReturnType<typeof setTimeout> | undefined;

    onStatusChanged(newStatus: string): void {
      setStatus(newStatus);
    }

    onReconnectScheduled(): void {
      setReconnect({
        attempt: this.attempt,
        lostAt: this.lostAt,
        nextRetryAt: this.nextRetryAt,
      });
    }

    onConnected(): void {
      setEverConnected(true);
      this.onReconnectScheduled();
      this.sendGetStatusRequest();
      this.sendGetSettingsRequest();
      this.sendGetScoreboardSports();
      this.sendGetGolfScoreboard();
      if (previewWanted) {
        this.sendStartPreview();
      }
    }

    reconnectSoon(): void {
      clearTimeout(this.statusTimerId);
      clearTimeout(this.settingsTimerId);
      this.statusTimerId = undefined;
      this.settingsTimerId = undefined;
      super.reconnectSoon();
    }

    handleResponse(_id: number, result: { ok: boolean }, data?: ResponseData): void {
      if (!result.ok || !data) return;
      if (data.getStatus !== undefined) {
        setStatusData(data.getStatus);
        this.statusTimerId = setTimeout(() => this.sendGetStatusRequest(), 1000);
      } else if (data.getSettings !== undefined) {
        const newSettings = data.getSettings.data;
        batch(() => {
          setSettings(newSettings);
          setSrtEnabled(newSettings.srt.connectionPrioritiesEnabled);
          setSrtPriorities(reconcile(newSettings.srt.connectionPriorities));
        });
        this.settingsTimerId = setTimeout(() => this.sendGetSettingsRequest(), 10000);
      } else if (data.getScoreboardSports !== undefined) {
        setSports(data.getScoreboardSports.names);
      } else if (data.getGolfScoreboard !== undefined) {
        setGolf(reconcile(data.getGolfScoreboard.data));
      }
    }

    handleEvent(data: EventData): void {
      if (data.state !== undefined) {
        applyState(data.state.data);
      } else if (data.log !== undefined) {
        const entry = data.log.entry;
        setLog((lines) => [...lines.slice(-(maximumLogLines - 1)), entry]);
      } else if (data.scoreboard !== undefined) {
        applyScoreboard(data.scoreboard.config);
      } else if (data.golfScoreboard !== undefined) {
        setGolf(reconcile(data.golfScoreboard.data));
      }
    }

    handlePreview(newPreview: string): void {
      if (previewWanted) {
        setPreview(`data:image/jpeg;base64,${newPreview}`);
      }
    }
  }

  const connection = new RemoteConnection();

  function setPreviewWanted(wanted: boolean): void {
    if (wanted === previewWanted) return;
    previewWanted = wanted;
    if (wanted) {
      connection.sendStartPreview();
    } else {
      connection.sendStopPreview();
      setPreview(null);
    }
  }

  function connected(): boolean {
    return status() === connectionStatus.connected;
  }

  return {
    connection,
    connected,
    everConnected,
    reconnect,
    state,
    setState,
    statusData,
    settings,
    srtEnabled,
    setSrtEnabled,
    srtPriorities,
    setSrtPriorities,
    log,
    setLog,
    preview,
    setPreviewWanted,
    scoreboard,
    setScoreboard,
    sports,
    clockRunning,
    setClockRunning,
    golf,
    setGolf,
  };
}

export type Remote = ReturnType<typeof createRemote>;
