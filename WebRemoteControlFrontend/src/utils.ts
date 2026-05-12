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

export interface ScoreboardTeamState {
  name: string;
  bgColor: string;
  textColor: string;
  primaryScore: string;
  secondaryScore: string;
  secondaryScore1: string;
  secondaryScore2: string;
  secondaryScore3: string;
  secondaryScore4: string;
  secondaryScore5: string;
  stat1: string;
  stat2: string;
  stat3: string;
  stat4: string;
  possession: boolean;
  [key: string]: string | boolean;
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
  maxSetScore: number;
  minSetScore: number;
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
  team1: ScoreboardTeamState;
  team2: ScoreboardTeamState;
  global: ScoreboardGlobalState;
  controls: Record<string, ScoreboardControlDef>;
  [key: string]:
    | ScoreboardTeamState
    | ScoreboardGlobalState
    | Record<string, ScoreboardControlDef>
    | string;
}

export interface ResponseData {
  getStatus?: Record<string, unknown>;
  getSettings?: { data: Record<string, unknown> };
  getScoreboardSports?: { names: string[] };
  getGolfScoreboard?: { data: RemoteControlGolfScoreboard };
}

export interface EventData {
  state?: { data: Record<string, unknown> };
  log?: { entry: string };
  scoreboard?: { config: Partial<ScoreboardMatchConfig> };
  golfScoreboard?: { data: RemoteControlGolfScoreboard };
}

interface IncomingMessage {
  ping?: unknown;
  response?: { id: number; result: ResponseResult; data: ResponseData };
  event?: { data: EventData };
  pong?: unknown;
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
