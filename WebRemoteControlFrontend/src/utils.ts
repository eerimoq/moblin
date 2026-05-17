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

export interface RemoteControlScoreboardTeam {
  name: string;
  bgColor: string;
  textColor: string;
  primaryScore: string;
  secondaryScore: string;
  secondaryScore1?: string;
  secondaryScore2?: string;
  secondaryScore3?: string;
  secondaryScore4?: string;
  secondaryScore5?: string;
  stat1: string;
  stat2: string;
  stat3: string;
  stat4: string;
  possession: boolean;
  [key: string]: string | boolean | undefined;
}

export function createScoreboardTeam(): RemoteControlScoreboardTeam {
  return {
    name: "",
    bgColor: "#000000",
    textColor: "#ffffff",
    primaryScore: "0",
    secondaryScore: "0",
    secondaryScore1: "",
    secondaryScore2: "",
    secondaryScore3: "",
    secondaryScore4: "",
    secondaryScore5: "",
    stat1: "",
    stat2: "",
    stat3: "",
    stat4: "",
    possession: false,
  };
}

export interface ScoreboardGlobalState {
  title: string;
  period: string;
  periodLabel: string;
  timer: string;
  timerDirection: string;
  duration: string;
  infoBoxText: string;
  scoringMode: string;
  showTitle: boolean;
  showStats: boolean;
  showMoreStats: boolean;
  showClock: boolean;
  changePossessionOnScore: boolean;
  [key: string]: string | boolean | number;
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
  team1: RemoteControlScoreboardTeam;
  team2: RemoteControlScoreboardTeam;
  global: ScoreboardGlobalState;
  controls: Record<string, ScoreboardControlDef>;
  [key: string]:
    | RemoteControlScoreboardTeam
    | ScoreboardGlobalState
    | Record<string, ScoreboardControlDef>
    | string;
}

export interface RemoteControlStatusGeneral {
  batteryCharging?: boolean;
  batteryLevel?: number;
  flame?: string;
  wiFiSsid?: string;
  isLive?: boolean;
  isRecording?: boolean;
  isMuted?: boolean;
}

export interface RemoteControlStatusItem {
  message: string;
  ok: boolean;
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

export interface RemoteControlStatusTopRightAudioInfo {
  // audioLevel: RemoteControlStatusTopRightAudioLevel
  numberOfAudioChannels: number;
}

export interface RemoteControlStatusTopRight {
  audioInfo?: RemoteControlStatusTopRightAudioInfo;
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

export interface RemoteControlResponseGetStatus {
  general?: RemoteControlStatusGeneral;
  topLeft: RemoteControlStatusTopLeft;
  topRight: RemoteControlStatusTopRight;
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

export interface RemoteControlSettings {
  scenes: NamedItem[];
  autoSceneSwitchers?: NamedItem[];
  bitratePresets: BitratePreset[];
  mics: NamedItem[];
  srt: RemoteControlSettingsSrt;
  gimbalPresets: GimbalPreset[];
}

export interface ResponseData {
  getStatus?: RemoteControlResponseGetStatus;
  getSettings?: { data: RemoteControlSettings };
  getScoreboardSports?: { names: string[] };
  getGolfScoreboard?: { data: RemoteControlGolfScoreboard };
}

export interface RemoteControlAssistantStreamerState {
  scene?: string;
  autoSceneSwitcher?: { id?: string };
  mic?: string;
  bitrate?: string;
  zoom?: number;
  zoomPresets?: ZoomPreset[];
  zoomPreset?: string;
  debugLogging?: boolean;
  streaming?: boolean;
  recording?: boolean;
  previewStream?: boolean;
  muted?: boolean;
  torchOn?: boolean;
  batteryCharging?: boolean;
  filters?: (object | boolean)[];
}

export function convertFilters(filters: (object | boolean)[]): [string, boolean][] {
  let result: [string, boolean][] = [];
  for (let index = 0; index < filters.length; index += 2) {
    const name = Object.keys(filters[index] as object)[0];
    const on = filters[index + 1] as boolean;
    result.push([name, on]);
  }
  return result;
}

export interface EventData {
  state?: { data: RemoteControlAssistantStreamerState };
  log?: { entry: string };
  scoreboard?: { config: ScoreboardMatchConfig };
  golfScoreboard?: { data: RemoteControlGolfScoreboard };
}

interface IncomingMessage {
  ping?: unknown;
  response?: { id: number; result: ResponseResult; data: ResponseData };
  event?: { data: EventData };
  pong?: unknown;
  preview?: { preview: string };
}

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

  setPreviewStream(on: boolean): void {
    this.sendRequest({ setPreviewStream: { on } });
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

  setFilter(filter: string, on: boolean): void {
    this.sendRequest({ setFilter: { filter: { [filter]: {} }, on } });
  }

  sendGetGolfScoreboard(): void {
    this.sendRequest({ getGolfScoreboard: {} });
  }

  updateGolfScoreboard(data: unknown): void {
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
    } else if (message.preview !== undefined) {
      this.handlePreview(message.preview.preview);
    }
  }

  handlePing(): void {
    this.send({ pong: {} });
  }

  handleResponse(_id: number, _result: ResponseResult, _data?: ResponseData): void {}

  handleEvent(_data: EventData): void {}

  handlePreview(_preview: string): void {}

  sendStartPreview(): void {
    this.sendRequest({ startPreview: {} });
  }

  sendStopPreview(): void {
    this.sendRequest({ stopPreview: {} });
  }

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

  setScoreboardDuration(minutes: number): void {
    this.sendRequest({
      setScoreboardDuration: { minutes: minutes },
    });
  }

  sendGetScoreboardSports(): void {
    this.sendRequest({ getScoreboardSports: {} });
  }

  sendToggleClock(): void {
    this.sendRequest({ toggleScoreboardClock: {} });
  }

  sendSetScoreboardClock(time: string): void {
    this.sendRequest({ setScoreboardClock: { time } });
  }

  sendUpdateScoreboard(config: ScoreboardMatchConfig): void {
    this.sendRequest({
      updateScoreboard: {
        config: config,
      },
    });
  }

  sendSetScoreboardSport(sportId: string): void {
    this.sendRequest({ setScoreboardSport: { sportId } });
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
