import type { JSX } from "solid-js";
import { createEffect, createSignal, For, Match, on, onCleanup, Show, Switch } from "solid-js";
import { twMerge } from "tailwind-merge";
import type { PageProps } from "./app.tsx";
import {
  Button,
  Card,
  Checkbox,
  HoldButton,
  Icon,
  Label,
  Segmented,
  Select,
  Slider,
  Switch as Toggle,
} from "./components.tsx";
import type { Remote } from "./remote.ts";
import { copyText, formatBitrate, RemoteControlStatusItem } from "./utils.ts";

const filters: [string, string][] = [
  ["pixellate", "Pixellate"],
  ["movie", "Movie"],
  ["grayScale", "Gray scale"],
  ["sepia", "Sepia"],
  ["triple", "Triple"],
  ["twin", "Twin"],
  ["fourThree", "4:3"],
  ["crt", "CRT"],
  ["pinch", "Pinch"],
  ["whirlpool", "Whirlpool"],
  ["poll", "Poll"],
  ["blurFaces", "Blur faces"],
  ["privacy", "Blur background"],
  ["beauty", "Beauty"],
  ["moblinInMouth", "Moblin in mouth"],
  ["cameraMan", "Camera man"],
];

const gimbalMotions: [string, string][] = [
  ["kapow", "Kapow"],
  ["yes", "Yes"],
  ["no", "No"],
  ["wakeup", "Wakeup"],
];

const flames: Record<string, [string, string]> = {
  White: ["Normal", "text-fg"],
  Yellow: ["Warm", "text-warning-fg"],
  Red: ["Hot", "text-danger-fg"],
};

const showPreviewKey = "show-preview";

function loadShowPreview(): boolean {
  return window.localStorage.getItem(showPreviewKey) !== "false";
}

function storeShowPreview(value: boolean): void {
  window.localStorage.setItem(showPreviewKey, value ? "true" : "false");
}

function Tile(props: {
  selected?: boolean;
  disabled?: boolean;
  class?: string;
  onClick: () => void;
  children: JSX.Element;
}) {
  return (
    <Button
      variant={props.selected ? "selected" : "control"}
      disabled={props.disabled}
      class={twMerge("min-w-0 text-center whitespace-normal", props.class)}
      onClick={() => props.onClick()}
    >
      {props.children}
    </Button>
  );
}

function SceneCard(props: PageProps) {
  const remote = props.remote;
  const [zoomText, setZoomText] = createSignal("");
  const [zoomSlider, setZoomSlider] = createSignal(1);

  createEffect(
    on(
      () => remote.state.zoom,
      (zoom) => {
        if (zoom === undefined) return;
        setZoomText(zoom.toFixed(1));
        setZoomSlider(zoom);
      },
    ),
  );

  function submitZoom(): void {
    const value = parseFloat(zoomText());
    if (!isNaN(value)) remote.connection.setZoom(value);
  }

  const autoSwitchers = () => [
    { value: "", label: "None" },
    ...(remote.settings()?.autoSceneSwitchers ?? []).map((item) => ({
      value: item.id,
      label: item.name,
    })),
  ];

  function togglePreviewStream(on: boolean): void {
    props.confirm({
      title: on ? "Start preview stream?" : "Stop preview stream?",
      message: on
        ? "Streams a low quality preview to the configured preview destination."
        : "Stops the preview stream.",
      confirmLabel: on ? "Start" : "Stop",
      confirmVariant: on ? "accent" : "danger",
      onConfirm: () => remote.connection.setPreviewStream(on),
    });
  }

  return (
    <Card class="gap-7 desktop:gap-9">
      <div class="flex flex-col gap-2.5">
        <div class="flex h-[26px] items-center justify-between">
          <Label>Scene</Label>
          <div class="flex items-center gap-2">
            <span class="text-[12px] text-muted">Auto switcher</span>
            <Select
              class="h-[26px] gap-1.5 rounded-md px-2.5 text-[12px]"
              options={autoSwitchers()}
              value={remote.state.autoSceneSwitcher}
              onChange={(value) =>
                remote.connection.setAutoSceneSwitcher(value === "" ? null : value)
              }
            />
          </div>
        </div>
        <div class="grid grid-cols-3 gap-2">
          <For each={remote.settings()?.scenes ?? []}>
            {(scene) => (
              <Tile
                selected={scene.id === remote.state.scene}
                class={twMerge(
                  "h-[60px] rounded-[10px] px-3.5 text-[14px] font-medium",
                  scene.id === remote.state.scene && "font-semibold",
                )}
                onClick={() => remote.connection.setScene(scene.id)}
              >
                {scene.name}
              </Tile>
            )}
          </For>
        </div>
      </div>
      <div class="flex flex-col gap-2.5">
        <div class="flex items-center justify-between">
          <Label>Zoom</Label>
          <span class="text-[12px]">
            {remote.state.zoom !== undefined ? `${remote.state.zoom.toFixed(1)}×` : ""}
          </span>
        </div>
        <Show when={remote.state.zoomPresets.length > 0}>
          <Segmented
            class="rounded-[10px]"
            itemClass="h-11 rounded-lg text-[14px]"
            options={remote.state.zoomPresets.map((preset) => ({
              value: preset.id,
              label: preset.name,
            }))}
            value={remote.state.zoomPreset ?? undefined}
            onChange={(id) => remote.connection.setZoomPreset(id)}
          />
        </Show>
        <div class="flex items-center gap-2.5 px-1 pt-1">
          <Slider
            min={0.5}
            max={10}
            step={0.1}
            value={zoomSlider()}
            onInput={(value) => {
              setZoomSlider(value);
              setZoomText(value.toFixed(1));
            }}
            onChange={(value) => remote.connection.setZoom(value)}
          />
          <input
            type="text"
            inputMode="decimal"
            class="h-[26px] w-14 rounded-md border border-control-stroke bg-control text-center text-[12px] outline-none focus:border-accent"
            value={zoomText()}
            onInput={(event) => setZoomText(event.currentTarget.value)}
            onKeyDown={(event) => {
              if (event.key === "Enter") event.currentTarget.blur();
            }}
            onBlur={submitZoom}
          />
        </div>
      </div>
      <div class="flex gap-3">
        <div class="flex min-w-0 flex-1 basis-0 flex-col gap-2">
          <Label>Mic</Label>
          <Select
            options={(remote.settings()?.mics ?? []).map((mic) => ({
              value: mic.id,
              label: mic.name,
            }))}
            value={remote.state.mic}
            onChange={(id) => remote.connection.setMic(id)}
          />
        </div>
        <div class="flex min-w-0 flex-1 basis-0 flex-col gap-2">
          <Label>Bitrate</Label>
          <Select
            options={(remote.settings()?.bitratePresets ?? []).map(({ id, bitrate }) => ({
              value: id,
              label: bitrate > 0 ? formatBitrate(bitrate) : "Unknown",
            }))}
            value={remote.state.bitrate}
            onChange={(id) => remote.connection.setBitratePreset(id)}
          />
        </div>
      </div>
      <div class="flex flex-col rounded-[10px] border border-divider">
        <div class="flex h-11 items-center justify-between border-b border-divider px-3.5">
          <span class="text-fg-2">Preview stream</span>
          <Toggle
            label="Preview stream"
            checked={remote.state.previewStream}
            onChange={togglePreviewStream}
          />
        </div>
        <div class="flex h-11 items-center justify-between px-3.5">
          <span class="text-fg-2">Browser widgets</span>
          <Button variant="small" onClick={() => remote.connection.reloadBrowserWidgets()}>
            <Icon name="reload" size={12} />
            Reload
          </Button>
        </div>
      </div>
    </Card>
  );
}

function Filters(props: { remote: Remote; columns: number }) {
  const remote = props.remote;
  const count = () => filters.filter(([key]) => remote.state.filters[key]).length;
  return (
    <div class="flex flex-col gap-2.5">
      <div class="flex h-[26px] items-center justify-between">
        <Label>Filters</Label>
        <Show when={count() > 0}>
          <span class="text-[11px] text-accent-fg">{count()} on</span>
        </Show>
      </div>
      <div
        class="grid gap-1.5"
        style={{ "grid-template-columns": `repeat(${props.columns}, minmax(0, 1fr))` }}
      >
        <For each={filters}>
          {([key, name]) => (
            <Tile
              selected={remote.state.filters[key] ?? false}
              class={twMerge(
                "h-10 rounded-lg px-2 text-[11px] leading-[1.2] tracking-[-0.02em] text-fg-2",
                remote.state.filters[key] && "font-medium text-accent-fg",
              )}
              onClick={() => {
                const on = !remote.state.filters[key];
                remote.setState("filters", key, on);
                remote.connection.setFilter(key, on);
              }}
            >
              {name}
            </Tile>
          )}
        </For>
      </div>
    </div>
  );
}

function Gimbal(props: { remote: Remote }) {
  const remote = props.remote;
  const disabled = () => remote.state.gimbalTracking;

  function Move(moveProps: { icon: "up" | "down" | "left" | "right"; x: number; y: number }) {
    return (
      <HoldButton
        class="size-[41px]"
        disabled={disabled()}
        onStart={() => remote.connection.setGimbalMovement(moveProps.x, moveProps.y)}
        onStop={() => remote.connection.setGimbalMovement(0, 0)}
      >
        <Icon name={moveProps.icon} size={14} stroke={2.5} />
      </HoldButton>
    );
  }

  return (
    <div class="flex flex-col gap-2.5">
      <div class="flex h-[26px] items-center justify-between">
        <Label>Gimbal</Label>
        <div class="flex items-center gap-2">
          <span class="text-[12px] text-muted">Tracking</span>
          <Toggle
            label="Tracking"
            checked={remote.state.gimbalTracking}
            onChange={(on) => remote.connection.setGimbalTracking(on)}
          />
        </div>
      </div>
      <Show when={disabled()}>
        <div class="text-[11px] text-faint">Turn tracking off to move the gimbal manually.</div>
      </Show>
      <div class="flex items-center gap-4">
        <div class="flex w-[132px] shrink-0 flex-col gap-1">
          <div class="flex justify-center gap-1">
            <Move icon="up" x={1} y={0} />
          </div>
          <div class="flex justify-center gap-1">
            <Move icon="left" x={0} y={1} />
            <div class="size-[41px]" />
            <Move icon="right" x={0} y={-1} />
          </div>
          <div class="flex justify-center gap-1">
            <Move icon="down" x={-1} y={0} />
          </div>
        </div>
        <div class="grid min-w-0 flex-1 grid-cols-2 gap-1.5">
          <For each={gimbalMotions}>
            {([motion, name]) => (
              <Tile
                class="h-10 rounded-lg text-[12px] text-fg-2"
                disabled={disabled()}
                onClick={() => remote.connection.animateGimbal(motion)}
              >
                {name}
              </Tile>
            )}
          </For>
          <For each={remote.state.gimbalPresets}>
            {(preset) => (
              <Tile
                class="h-10 rounded-lg text-[12px] text-fg-2"
                disabled={disabled()}
                onClick={() => remote.connection.moveToGimbalPreset(preset.id)}
              >
                {preset.name}
              </Tile>
            )}
          </For>
          <Button
            variant="dashed"
            class="col-span-2 h-[34px] rounded-lg text-[12px] text-muted"
            disabled={disabled()}
            onClick={() => remote.connection.saveGimbalPreset()}
          >
            Save current position
          </Button>
        </div>
      </div>
    </div>
  );
}

function SrtPriorities(props: { remote: Remote }) {
  const remote = props.remote;

  function update(index: number, priority: number, enabled: boolean, send: boolean): void {
    remote.setSrtPriorities(index, { priority, enabled });
    if (send) {
      remote.connection.setSrtConnectionPriority(remote.srtPriorities[index].id, priority, enabled);
    }
  }

  return (
    <Show when={remote.srtPriorities.length > 0}>
      <div class="flex flex-col gap-3">
        <div class="flex items-center justify-between">
          <Label>SRT connection priorities</Label>
          <Toggle
            label="SRT connection priorities"
            checked={remote.srtEnabled()}
            onChange={(on) => {
              remote.setSrtEnabled(on);
              remote.connection.setSrtConnectionPrioritiesEnabled(on);
            }}
          />
        </div>
        <For each={remote.srtPriorities}>
          {(priority, index) => (
            <div class="flex items-center gap-3">
              <Checkbox
                checked={priority.enabled}
                onChange={(on) => update(index(), priority.priority, on, true)}
              />
              <div
                class={twMerge(
                  "w-16 truncate text-[12px]",
                  priority.enabled ? "text-fg-2" : "text-muted",
                )}
              >
                {priority.name}
              </div>
              <Slider
                min={1}
                max={10}
                value={priority.priority}
                off={!priority.enabled}
                onInput={(value) => update(index(), value, priority.enabled, false)}
                onChange={(value) => update(index(), value, priority.enabled, true)}
              />
              <div
                class={twMerge(
                  "w-16 text-right text-[11px]",
                  priority.enabled ? "text-muted" : "text-faint",
                )}
              >
                {priority.enabled ? `P${priority.priority}` : "off"}
              </div>
            </div>
          )}
        </For>
      </div>
    </Show>
  );
}

function EffectsCard(props: PageProps) {
  return (
    <Card class="gap-7 desktop:gap-9">
      <Filters remote={props.remote} columns={props.layout() === "desktop" ? 4 : 3} />
      <Gimbal remote={props.remote} />
      <SrtPriorities remote={props.remote} />
    </Card>
  );
}

type StatusRow = [string, string, string];

function statusRows(remote: Remote): StatusRow[] {
  const status = remote.statusData();
  if (status === null) return [];
  const rows: StatusRow[] = [];
  const add = (name: string, item?: RemoteControlStatusItem) => {
    if (item !== undefined)
      rows.push([name, item.message, item.ok === false ? "text-warning-fg" : ""]);
  };
  const { general, topLeft, topRight } = status;
  add("Stream", topLeft.stream);
  add("Camera", topLeft.camera);
  add("Mic", topLeft.mic);
  add("Zoom", topLeft.zoom);
  if (general?.wiFiSsid !== undefined) rows.push(["WiFi", general.wiFiSsid, ""]);
  add("Chat", topLeft.chat);
  add("OBS", topLeft.obs);
  add("Events", topLeft.events);
  add("Location", topRight.location);
  add("Bonding", topRight.srtla);
  add("Bonding RTTs", topRight.srtlaRtts);
  add("Ingests", topRight.rtmpServer);
  add("Moblink", topRight.moblink);
  add("Recording", topRight.recording);
  add("Replay", topRight.replay);
  add("Browser widgets", topRight.browserWidgets);
  add("Remote control", topRight.remoteControl);
  add("Game controller", topRight.gameController);
  add("DJI devices", topRight.djiDevices);
  add("System monitor", topRight.systemMonitor);
  if (general?.flame !== undefined) {
    const [text, color] = flames[general.flame] ?? [general.flame, ""];
    rows.push(["Flame", text, color]);
  }
  return rows;
}

function Preview(props: { remote: Remote; show: boolean; onShow: () => void; onHide: () => void }) {
  return (
    <div class="relative aspect-video w-full overflow-hidden rounded-[10px] bg-well">
      <Switch>
        <Match when={!props.show}>
          <button
            type="button"
            class="flex size-full flex-col items-center justify-center gap-1.5 text-[11px] text-muted"
            onClick={() => props.onShow()}
          >
            <Icon name="eye" size={16} />
            Show preview
          </button>
        </Match>
        <Match when={props.remote.preview() === null}>
          <div class="flex size-full items-center justify-center text-[11px] text-muted">
            Loading…
          </div>
        </Match>
        <Match when={props.remote.preview()}>
          {(src) => (
            <button type="button" class="size-full" onClick={() => props.onHide()}>
              <img src={src()} alt="Video preview" class="size-full object-cover" />
            </button>
          )}
        </Match>
      </Switch>
      <div class="pointer-events-none absolute top-1.5 left-1.5 flex h-4 items-center rounded px-[5px] text-[9px] text-[#ededed] bg-[rgb(10_10_11/0.7)]">
        PREVIEW
      </div>
    </div>
  );
}

function MonitorCard(
  props: PageProps & { showPreview: boolean; setShowPreview: (show: boolean) => void },
) {
  const remote = props.remote;
  const stats = (): [string, string][] => {
    const status = remote.statusData();
    const battery = status?.general?.batteryLevel;
    return [
      ["Bitrate", status?.topRight.bitrate?.message.split(" (")[0] ?? "-"],
      ["Audio", status?.topRight.audioLevel?.message ?? "-"],
      ["Viewers", status?.topLeft.viewers?.message ?? "-"],
      [
        "Battery",
        battery !== undefined ? `${battery}%${status?.general?.batteryCharging ? " ⚡" : ""}` : "-",
      ],
    ];
  };
  return (
    <Card
      class={twMerge("gap-7 desktop:gap-9", props.layout() === "desktop" && "w-[380px] shrink-0")}
    >
      <div class="flex flex-col gap-3">
        <Preview
          remote={remote}
          show={props.showPreview}
          onShow={() => props.setShowPreview(true)}
          onHide={() => props.setShowPreview(false)}
        />
        <div class="grid grid-cols-2 gap-x-3 gap-y-2.5">
          <For each={stats()}>
            {([name, value]) => (
              <div class="flex min-w-0 flex-col gap-1">
                <span class="text-[11px] text-muted">{name}</span>
                <span class="truncate text-[13px]">{value}</span>
              </div>
            )}
          </For>
        </div>
      </div>
      <div class="flex flex-col gap-2">
        <Label>Status</Label>
        <div class="flex flex-col rounded-[10px] border border-divider px-3.5 py-1">
          <For
            each={statusRows(remote)}
            fallback={<div class="py-2 text-[12px] text-faint">Waiting for status…</div>}
          >
            {([name, value, color]) => (
              <div class="flex justify-between gap-4 border-b border-divider py-2 text-[12px] last:border-b-0">
                <span class="shrink-0 text-muted">{name}</span>
                <span class={twMerge("min-w-0 text-right break-words", color)}>{value}</span>
              </div>
            )}
          </For>
        </div>
      </div>
    </Card>
  );
}

function LogCard(props: PageProps) {
  const remote = props.remote;
  const [copied, setCopied] = createSignal<string | null>(null);
  let well: HTMLDivElement | undefined;
  let stickToBottom = true;

  createEffect(
    on(remote.log, () => {
      if (well && stickToBottom) well.scrollTop = well.scrollHeight;
    }),
  );

  async function copy(): Promise<void> {
    try {
      await copyText(remote.log().join("\n"));
      setCopied("Copied");
    } catch {
      setCopied("Failed");
    }
    setTimeout(() => setCopied(null), 1500);
  }

  const desktop = () => props.layout() === "desktop";

  return (
    <Card class="gap-2.5 desktop:px-8">
      <div class="flex items-center justify-between gap-3">
        <div class="flex items-center gap-4">
          <Label>Log</Label>
          <Show when={desktop()}>
            <span class="text-[11px] text-faint">
              {remote.log().length} {remote.log().length === 1 ? "line" : "lines"}
            </span>
          </Show>
        </div>
        <div class="flex items-center gap-2 tablet:gap-4">
          <div class="flex items-center gap-2">
            <span class="text-[12px] text-muted">{desktop() ? "Debug logging" : "Debug"}</span>
            <Toggle
              label="Debug logging"
              checked={remote.state.debugLogging}
              onChange={(on) => remote.connection.setDebugLogging(on)}
            />
          </div>
          <Button variant="small" onClick={copy}>
            <Icon name="copy" size={12} />
            {copied() ?? "Copy"}
          </Button>
          <Button variant="small" onClick={() => remote.setLog([])}>
            <Icon name="trash" size={12} />
            Clear
          </Button>
        </div>
      </div>
      <div
        ref={(element) => (well = element)}
        class={twMerge(
          "h-[280px] overflow-auto rounded-[10px] border border-divider bg-well px-3 py-3.5 text-[12px] leading-[21px] text-muted select-text tablet:px-4",
          desktop() ? "whitespace-pre" : "whitespace-pre-wrap",
        )}
        onScroll={(event) => {
          const element = event.currentTarget;
          stickToBottom = element.scrollHeight - element.scrollTop - element.clientHeight < 24;
        }}
      >
        <Show
          when={remote.log().length > 0}
          fallback={<span class="text-faint">No log entries yet.</span>}
        >
          {remote.log().join("\n")}
        </Show>
      </div>
    </Card>
  );
}

export function ControlPage(props: PageProps) {
  const [showPreview, setShowPreview] = createSignal(loadShowPreview());

  createEffect(() => props.remote.setPreviewWanted(showPreview()));
  onCleanup(() => props.remote.setPreviewWanted(false));

  function changeShowPreview(show: boolean): void {
    storeShowPreview(show);
    setShowPreview(show);
  }

  const monitor = () => (
    <MonitorCard {...props} showPreview={showPreview()} setShowPreview={changeShowPreview} />
  );

  return (
    <Switch>
      <Match when={props.layout() === "desktop"}>
        <div class="flex flex-col gap-4">
          <div class="flex gap-4">
            {monitor()}
            <div class="flex min-w-0 flex-1 basis-0 *:flex-1">
              <SceneCard {...props} />
            </div>
            <div class="flex min-w-0 flex-1 basis-0 *:flex-1">
              <EffectsCard {...props} />
            </div>
          </div>
          <LogCard {...props} />
        </div>
      </Match>
      <Match when={props.layout() === "tablet"}>
        <div class="flex items-start gap-4">
          <div class="flex min-w-0 flex-1 basis-0 flex-col gap-4">
            {monitor()}
            <SceneCard {...props} />
          </div>
          <div class="flex min-w-0 flex-1 basis-0 flex-col gap-4">
            <EffectsCard {...props} />
            <LogCard {...props} />
          </div>
        </div>
      </Match>
      <Match when={props.layout() === "mobile"}>
        <div class="flex flex-col gap-3">
          {monitor()}
          <SceneCard {...props} />
          <EffectsCard {...props} />
          <LogCard {...props} />
        </div>
      </Match>
    </Switch>
  );
}
