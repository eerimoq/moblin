import { websocketPort } from "/js/config.mjs";
import type { Setter } from "solid-js";

export function websocketUrl(): string {
  return `ws://${window.location.hostname}:${websocketPort}`;
}

export const connectionStatus = {
  connecting: "Connecting...",
  connected: "Connected",
} as const;

export type ConnectionStatus = (typeof connectionStatus)[keyof typeof connectionStatus];

interface ResponseResult {
  ok: boolean;
}

// ---------- Status types (mirrors RemoteControlStatus* in Swift) ----------

type RemoteControlStatusGeneralFlame = "White" | "Yellow" | "Red";

export interface RemoteControlStatusItem {
  message: string;
  ok: boolean;
}

export interface RemoteControlStatusGeneral {
  batteryCharging?: boolean;
  batteryLevel?: number;
  flame?: RemoteControlStatusGeneralFlame;
  wiFiSsid?: string;
  isLive?: boolean;
  isRecording?: boolean;
  isMuted?: boolean;
}

export interface RemoteControlStatusTopLeft {
  stream?: RemoteControlStatusItem;
  camera?: RemoteControlStatusItem;
  mic?: RemoteControlStatusItem;
  zoom?: RemoteControlStatusItem;
  obs?: RemoteControlStatusItem;
  events?: RemoteControlStatusItem;
  chat?: RemoteControlStatusItem;
  viewers?: RemoteControlStatusItem;
}

export interface RemoteControlStatusTopRight {
  audioLevel?: RemoteControlStatusItem;
  rtmpServer?: RemoteControlStatusItem;
  remoteControl?: RemoteControlStatusItem;
  gameController?: RemoteControlStatusItem;
  bitrate?: RemoteControlStatusItem;
  uptime?: RemoteControlStatusItem;
  location?: RemoteControlStatusItem;
  srtla?: RemoteControlStatusItem;
  srtlaRtts?: RemoteControlStatusItem;
  recording?: RemoteControlStatusItem;
  replay?: RemoteControlStatusItem;
  browserWidgets?: RemoteControlStatusItem;
  moblink?: RemoteControlStatusItem;
  djiDevices?: RemoteControlStatusItem;
  systemMonitor?: RemoteControlStatusItem;
}

// ---------- Settings types (mirrors RemoteControlSettings* in Swift) ----------

export interface RemoteControlSettingsScene {
  id: string;
  name: string;
}

export interface RemoteControlSettingsAutoSceneSwitcher {
  id: string;
  name: string;
}

export interface RemoteControlSettingsBitratePreset {
  id: string;
  bitrate: number;
}

export interface RemoteControlSettingsMic {
  id: string;
  name: string;
}

export interface RemoteControlSettingsSrtConnectionPriority {
  id: string;
  name: string;
  priority: number;
  enabled: boolean;
}

export interface RemoteControlSettingsSrt {
  connectionPrioritiesEnabled: boolean;
  connectionPriorities: RemoteControlSettingsSrtConnectionPriority[];
}

export interface RemoteControlSettingsGimbalPreset {
  id: string;
  name: string;
}

export interface RemoteControlSettings {
  scenes: RemoteControlSettingsScene[];
  autoSceneSwitchers?: RemoteControlSettingsAutoSceneSwitcher[];
  bitratePresets: RemoteControlSettingsBitratePreset[];
  mics: RemoteControlSettingsMic[];
  srt: RemoteControlSettingsSrt;
  gimbalPresets: RemoteControlSettingsGimbalPreset[];
}

// ---------- Streamer state types (mirrors RemoteControlAssistantStreamerState in Swift) ----------

interface RemoteControlStateAutoSceneSwitcher {
  id?: string;
}

export type RemoteControlFilterName =
  | "pixellate"
  | "movie"
  | "grayScale"
  | "sepia"
  | "triple"
  | "twin"
  | "fourThree"
  | "crt"
  | "pinch"
  | "whirlpool"
  | "poll"
  | "blurFaces"
  | "privacy"
  | "beauty"
  | "moblinInMouth"
  | "cameraMan";

// Swift encodes [RemoteControlFilter: Bool] as a flat alternating array:
// [{ filterName: {} }, boolean, { filterName: {} }, boolean, ...]
type FilterKeyObject = { [K in RemoteControlFilterName]?: Record<string, never> };
type FiltersArray = Array<FilterKeyObject | boolean>;

export interface RemoteControlAssistantStreamerState {
  scene?: string;
  autoSceneSwitcher?: RemoteControlStateAutoSceneSwitcher;
  mic?: string;
  bitrate?: string;
  zoom?: number;
  zoomPresets?: ZoomPreset[];
  zoomPreset?: string;
  debugLogging?: boolean;
  streaming?: boolean;
  recording?: boolean;
  muted?: boolean;
  torchOn?: boolean;
  batteryCharging?: boolean;
  filters?: FiltersArray;
}

// ---------- Golf scoreboard (mirrors RemoteControlGolfScoreboard in Swift) ----------

export interface RemoteControlGolfPlayer {
  name: string;
  scores: number[];
}

export interface RemoteControlGolfScoreboard {
  title: string;
  numberOfHoles: number;
  pars: number[];
  currentHole: number;
  players: RemoteControlGolfPlayer[];
}

// ---------- Scoreboard types (mirrors RemoteControlScoreboard* in Swift) ----------

export interface ScoreboardTeamState {
  name: string;
  bgColor: string;
  textColor: string;
  possession: boolean;
  primaryScore: string;
  secondaryScore: string;
  secondaryScoreLabel?: string;
  secondaryScore1?: string;
  secondaryScore2?: string;
  secondaryScore3?: string;
  secondaryScore4?: string;
  secondaryScore5?: string;
  stat1: string;
  stat1Label: string;
  stat2: string;
  stat2Label: string;
  stat3: string;
  stat3Label: string;
  stat4: string;
  stat4Label: string;
}

export interface ScoreboardGlobalState {
  title: string;
  timer: string;
  timerDirection: string;
  duration?: number;
  period: string;
  periodLabel: string;
  infoBoxText: string;
  primaryScoreResetOnPeriod?: boolean;
  secondaryScoreResetOnPeriod?: boolean;
  changePossessionOnScore?: boolean;
  scoringMode?: string;
  minSetScore?: number;
  maxSetScore?: number;
  showTitle?: boolean;
  showStats?: boolean;
  showMoreStats?: boolean;
  showClock?: boolean;
}

export interface ScoreboardControlDef {
  type: string;
  label?: string;
  options?: string[];
  periodReset?: boolean;
}

export interface ScoreboardMatchConfig {
  sportId: string;
  layout: string;
  team1: ScoreboardTeamState;
  team2: ScoreboardTeamState;
  global: ScoreboardGlobalState;
  controls: Record<string, ScoreboardControlDef>;
}

// ---------- Message envelope types ----------

export interface ResponseData {
  getStatus?: {
    general?: RemoteControlStatusGeneral;
    topLeft?: RemoteControlStatusTopLeft;
    topRight?: RemoteControlStatusTopRight;
  };
  getSettings?: { data: RemoteControlSettings };
  getScoreboardSports?: { names: string[] };
  getGolfScoreboard?: { data: RemoteControlGolfScoreboard };
}

export interface EventData {
  state?: { data: RemoteControlAssistantStreamerState };
  log?: { entry: string };
  status?: {
    general?: RemoteControlStatusGeneral;
    topLeft?: RemoteControlStatusTopLeft;
    topRight?: RemoteControlStatusTopRight;
  };
  scoreboard?: { config: ScoreboardMatchConfig };
  golfScoreboard?: { data: RemoteControlGolfScoreboard };
}

interface IncomingMessage {
  ping?: Record<string, never>;
  response?: { id: number; result: ResponseResult; data: ResponseData };
  event?: { data: EventData };
  pong?: Record<string, never>;
}

// ---------- Convenience aliases (kept for call-site compatibility) ----------

export interface NamedItem {
  id: string;
  name: string;
}

export interface ZoomPreset extends NamedItem {}

export interface BitratePreset {
  id: string;
  bitrate: number;
}

export interface SrtPriority {
  id: string;
  name: string;
  priority: number;
  enabled: boolean;
}

export interface GimbalPreset extends NamedItem {}

export class WebSocketConnection {
  protected connectTimerId: ReturnType<typeof setTimeout> | undefined;
  protected nextId: number;
  protected status: string;
  protected websocket!: WebSocket;

  constructor() {
    this.connectTimerId = undefined;
    this.nextId = 1;
    this.status = connectionStatus.connecting;
    this.connect();
  }

  connect(): void {
    this.websocket = new WebSocket(websocketUrl());
    this.websocket.onopen = () => {
      this.setStatus(connectionStatus.connected);
      this.onConnected();
    };
    this.websocket.onerror = () => {
      this.reconnectSoon();
    };
    this.websocket.onclose = () => {
      this.reconnectSoon();
    };
    this.websocket.onmessage = async (event: MessageEvent<string>) => {
      const message = JSON.parse(event.data) as IncomingMessage;
      await this.handleMessage(message);
    };
  }

  reconnectSoon(): void {
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

  setStatus(newStatus: string): void {
    if (this.status == newStatus) {
      return;
    }
    this.status = newStatus;
    this.onStatusChanged(newStatus);
  }

  onStatusChanged(_newStatus: string): void {}

  onConnected(): void {}

  setLive(on: boolean): void {
    this.sendRequest({ setStream: { on } });
  }

  setRecording(on: boolean): void {
    this.sendRequest({ setRecord: { on } });
  }

  setMuted(on: boolean): void {
    this.sendRequest({ setMute: { on } });
  }

  setDebugLogging(on: boolean): void {
    this.sendRequest({ setDebugLogging: { on } });
  }

  setZoom(zoomLevel: number): void {
    this.sendRequest({ setZoom: { x: zoomLevel } });
  }

  setZoomPreset(id: string): void {
    this.sendRequest({ setZoomPreset: { id } });
  }

  setScene(id: string): void {
    this.sendRequest({ setScene: { id } });
  }

  setAutoSceneSwitcher(id: string | null): void {
    this.sendRequest({ setAutoSceneSwitcher: { id } });
  }

  setMic(id: string): void {
    this.sendRequest({ setMic: { id } });
  }

  setBitratePreset(id: string): void {
    this.sendRequest({ setBitratePreset: { id } });
  }

  reloadBrowserWidgets(): void {
    this.sendRequest({ reloadBrowserWidgets: {} });
  }

  setSrtConnectionPrioritiesEnabled(enabled: boolean): void {
    this.sendRequest({ setSrtConnectionPrioritiesEnabled: { enabled } });
  }

  setSrtConnectionPriority(id: string, priority: number, enabled: boolean): void {
    this.sendRequest({ setSrtConnectionPriority: { id, priority, enabled } });
  }

  moveToGimbalPreset(id: string): void {
    this.sendRequest({ moveToGimbalPreset: { id } });
  }

  setFilter(filter: RemoteControlFilterName, on: boolean): void {
    this.sendRequest({ setFilter: { filter: { [filter]: {} }, on } });
  }

  sendGetGolfScoreboard(): void {
    this.sendRequest({ getGolfScoreboard: {} });
  }

  updateGolfScoreboard(data: RemoteControlGolfScoreboard): void {
    this.sendRequest({ updateGolfScoreboard: { data } });
  }

  getNextId(): number {
    this.nextId += 1;
    return this.nextId;
  }

  async handleMessage(message: IncomingMessage): Promise<void> {
    if (message.ping !== undefined) {
      this.handlePing();
    } else if (message.response !== undefined) {
      this.handleResponse(message.response.id, message.response.result, message.response.data);
    } else if (message.event !== undefined) {
      this.handleEvent(message.event.data);
    }
  }

  handlePing(): void {
    this.send({ pong: {} });
  }

  handleResponse(_id: number, _result: ResponseResult, _data?: ResponseData): void {}

  handleEvent(_data: EventData): void {}

  sendGetStatusRequest(): void {
    this.sendRequest({ getStatus: {} });
  }

  sendGetSettingsRequest(): void {
    this.sendRequest({ getSettings: {} });
  }

  sendStartStatusRequest(): void {
    this.sendRequest({
      startStatus: {
        interval: 1,
        filter: { topRight: true },
      },
    });
  }

  sendRequest(data: unknown): void {
    this.send({
      request: {
        id: this.getNextId(),
        data,
      },
    });
  }

  send(message: unknown): void {
    this.websocket.send(JSON.stringify(message));
  }
}

let confirmComplete: ((result: boolean) => void) | null = null;
let confirmResult = false;

export async function showConfirm(
  message: string,
  setConfirmMessage: Setter<string>,
  setConfirmOpen: Setter<boolean>,
): Promise<boolean> {
  setConfirmMessage(message);
  setConfirmOpen(true);
  await new Promise<void>((resolve) => {
    confirmComplete = (result: boolean) => {
      confirmResult = result;
      resolve();
    };
  });
  setConfirmOpen(false);
  return confirmResult;
}

export function confirmOk(): void {
  if (confirmComplete) confirmComplete(true);
}

export function confirmCancel(): void {
  if (confirmComplete) confirmComplete(false);
}
