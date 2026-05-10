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

interface IncomingMessage {
  ping?: unknown;
  response?: { id: number; result: ResponseResult; data: unknown };
  event?: { data: unknown };
  pong?: unknown;
}

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
    this.sendRequest("reloadBrowserWidgets");
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
    } else if (message.response) {
      this.handleResponse(message.response.id, message.response.result, message.response.data);
    } else if (message.event) {
      this.handleEvent(message.event.data);
    }
  }

  handlePing(): void {
    this.send({ pong: {} });
  }

  handleResponse(_id: number, _result: ResponseResult, _data: unknown): void {}

  handleEvent(_data: unknown): void {}

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
