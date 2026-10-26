import type { Accessor, JSX } from "solid-js";
import {
  createEffect,
  createSignal,
  For,
  Match,
  onCleanup,
  onMount,
  Show,
  Switch as SolidSwitch,
} from "solid-js";
import { render } from "solid-js/web";
import { twMerge } from "tailwind-merge";
import { Button, Chevron, Dialog, DialogConfig, Icon, IconName, Label } from "./components.tsx";
import { ControlPage } from "./control.tsx";
import { GolfPage } from "./golf.tsx";
import { RecordingsPage } from "./recordings.tsx";
import { createRemote, Remote } from "./remote.ts";
import { ScoreboardPage } from "./scoreboardControl.tsx";

type Tab = "control" | "scoreboard" | "golf" | "recordings";

const tabs: { id: Tab; label: string; path: string; title: string }[] = [
  { id: "control", label: "Control", path: "/", title: "Moblin Remote Control" },
  { id: "scoreboard", label: "Scoreboard", path: "/remote.html", title: "Moblin Scoreboard" },
  { id: "golf", label: "Golf", path: "/golf.html", title: "Moblin Golf Scoreboard" },
  { id: "recordings", label: "Recordings", path: "/recordings.html", title: "Moblin Recordings" },
];

function tabFromPath(path: string): Tab {
  return tabs.find((tab) => tab.path !== "/" && path.endsWith(tab.path))?.id ?? "control";
}

export type Layout = "mobile" | "tablet" | "desktop";

export interface PageProps {
  remote: Remote;
  layout: Accessor<Layout>;
  confirm: (config: DialogConfig) => void;
}

function createLayout(): Accessor<Layout> {
  const desktop = window.matchMedia("(min-width: 80rem)");
  const tablet = window.matchMedia("(min-width: 40rem)");
  const current = (): Layout =>
    desktop.matches ? "desktop" : tablet.matches ? "tablet" : "mobile";
  const [layout, setLayout] = createSignal<Layout>(current());
  const update = () => setLayout(current());
  desktop.addEventListener("change", update);
  tablet.addEventListener("change", update);
  onCleanup(() => {
    desktop.removeEventListener("change", update);
    tablet.removeEventListener("change", update);
  });
  return layout;
}

type ThemeChoice = "system" | "light" | "dark";

const themeKey = "theme";

const themeChoices: { id: ThemeChoice; label: string; icon: IconName }[] = [
  { id: "system", label: "System", icon: "monitor" },
  { id: "light", label: "Light", icon: "sun" },
  { id: "dark", label: "Dark", icon: "moon" },
];

function loadTheme(): ThemeChoice {
  const value = window.localStorage.getItem(themeKey);
  return value === "light" || value === "dark" ? value : "system";
}

function createTheme(): [Accessor<ThemeChoice>, (choice: ThemeChoice) => void] {
  const [theme, setTheme] = createSignal<ThemeChoice>(loadTheme());
  const prefersLight = window.matchMedia("(prefers-color-scheme: light)");
  const [systemLight, setSystemLight] = createSignal(prefersLight.matches);
  const update = () => setSystemLight(prefersLight.matches);
  prefersLight.addEventListener("change", update);
  onCleanup(() => prefersLight.removeEventListener("change", update));
  createEffect(() => {
    const light = theme() === "light" || (theme() === "system" && systemLight());
    if (light) {
      document.documentElement.dataset.theme = "light";
    } else {
      delete document.documentElement.dataset.theme;
    }
  });
  function choose(choice: ThemeChoice): void {
    window.localStorage.setItem(themeKey, choice);
    setTheme(choice);
  }
  return [theme, choose];
}

function ThemeButton(props: {
  theme: ThemeChoice;
  onChange: (choice: ThemeChoice) => void;
  compact?: boolean;
}) {
  const [open, setOpen] = createSignal(false);
  let container: HTMLDivElement | undefined;

  function onPointerDown(event: PointerEvent): void {
    if (container && !container.contains(event.target as Node)) setOpen(false);
  }

  onMount(() => {
    document.addEventListener("pointerdown", onPointerDown);
    onCleanup(() => document.removeEventListener("pointerdown", onPointerDown));
  });

  const icon = () => themeChoices.find((choice) => choice.id === props.theme)!.icon;

  return (
    <div class="relative" ref={(element) => (container = element)}>
      <button
        type="button"
        aria-label="Theme"
        class={twMerge(
          "flex items-center gap-1.5 rounded-lg border border-control-stroke pr-2 pl-[9px] text-fg",
          props.compact ? "h-7" : "h-8",
          open() ? "bg-selected" : "bg-control",
        )}
        onClick={() => setOpen(!open())}
      >
        <Icon name={icon()} size={props.compact ? 14 : 15} />
        <Chevron class="w-2" />
      </button>
      <Show when={open()}>
        <div
          class={twMerge(
            "absolute top-[calc(100%+8px)] z-40 flex w-46 flex-col gap-0.5 rounded-[10px] border border-card-stroke bg-card p-1 shadow-[0_12px_32px_rgb(0_0_0/0.5)]",
            props.compact ? "right-0" : "left-0",
          )}
        >
          <Label class="px-2.5 pt-2 pb-1">Theme</Label>
          <For each={themeChoices}>
            {(choice) => (
              <button
                type="button"
                class={twMerge(
                  "flex h-8 items-center gap-2.5 rounded-md px-2.5 text-[12px]",
                  choice.id === props.theme
                    ? "bg-selected font-medium text-fg"
                    : "text-fg-2 active:bg-selected",
                )}
                onClick={() => {
                  props.onChange(choice.id);
                  setOpen(false);
                }}
              >
                <Icon
                  name={choice.icon}
                  size={14}
                  class={choice.id === props.theme ? "text-fg" : "text-muted"}
                />
                <span class="flex-1 text-left">{choice.label}</span>
                <Show when={choice.id === props.theme} fallback={<div class="size-3.5" />}>
                  <Icon name="check" size={14} stroke={2.6} class="text-accent-fg" />
                </Show>
              </button>
            )}
          </For>
        </div>
      </Show>
    </div>
  );
}

function TabBar(props: { tab: Tab; onSelect: (tab: Tab) => void }) {
  return (
    <nav class="flex gap-0.5 rounded-lg bg-control p-[3px]">
      <For each={tabs}>
        {(tab) => (
          <button
            type="button"
            class={twMerge(
              "rounded-md px-3 py-1.5 text-[12px]",
              tab.id === props.tab ? "bg-selected font-medium text-fg" : "text-muted",
            )}
            onClick={() => props.onSelect(tab.id)}
          >
            {tab.label}
          </button>
        )}
      </For>
    </nav>
  );
}

function BottomTabBar(props: { tab: Tab; onSelect: (tab: Tab) => void }) {
  return (
    <nav class="sticky bottom-0 z-30 flex gap-1 border-t border-card-stroke bg-bar px-3 pt-2 pb-[max(28px,env(safe-area-inset-bottom))]">
      <For each={tabs}>
        {(tab) => (
          <button
            type="button"
            class={twMerge(
              "flex-1 basis-0 rounded-md py-1.5 text-[11px]",
              tab.id === props.tab ? "bg-selected font-medium text-fg" : "text-muted",
            )}
            onClick={() => props.onSelect(tab.id)}
          >
            {tab.label}
          </button>
        )}
      </For>
    </nav>
  );
}

function LiveIndicator(props: { remote: Remote; compact?: boolean }) {
  const uptime = () => props.remote.statusData()?.topRight.uptime?.message ?? "";
  const live = () => props.remote.connected() && props.remote.state.streaming;
  const text = () => {
    if (!props.remote.connected()) return "NO CONNECTION";
    if (!props.remote.state.streaming) return "OFFLINE";
    return uptime() !== "" && uptime() !== "-" ? `LIVE ${uptime()}` : "LIVE";
  };
  return (
    <div class={twMerge("flex items-center", props.compact ? "gap-2" : "gap-2.5")}>
      <div
        class={twMerge(
          "rounded-full",
          props.compact ? "size-2" : "size-[9px]",
          live() ? "bg-danger" : "bg-faint",
          live() && !props.compact && "shadow-[0_0_0_4px_rgb(255_59_48/0.18)]",
        )}
      />
      <div
        class={twMerge(
          "font-medium whitespace-nowrap",
          props.compact ? "text-base" : "text-xl",
          live() ? "text-fg" : "text-muted",
        )}
      >
        {text()}
      </div>
    </div>
  );
}

interface ActionsProps {
  remote: Remote;
  layout: Layout;
  confirm: (config: DialogConfig) => void;
}

function Actions(props: ActionsProps) {
  const remote = props.remote;
  const mobile = () => props.layout === "mobile";
  const stretch = () => props.layout !== "desktop";

  function endStreamMessage(): string {
    const uptime = remote.statusData()?.topRight.uptime?.message;
    const viewers = remote.statusData()?.topLeft.viewers?.message;
    let message = "";
    if (uptime && uptime !== "-") {
      message = `You've been live for ${uptime}`;
      if (viewers && viewers !== "-") message += ` with ${viewers} viewers`;
      message += ". ";
    }
    return message + "Ending stops the broadcast for everyone.";
  }

  function toggleLive(): void {
    if (remote.state.streaming) {
      props.confirm({
        title: "End stream?",
        message: endStreamMessage(),
        cancelLabel: "Keep streaming",
        confirmLabel: "End stream",
        onConfirm: () => remote.connection.setLive(false),
      });
    } else {
      props.confirm({
        title: "Go live?",
        message: "Starts the broadcast with the current stream settings.",
        confirmLabel: "Go live",
        confirmVariant: "accent",
        onConfirm: () => remote.connection.setLive(true),
      });
    }
  }

  function toggleRecording(): void {
    if (remote.state.recording) {
      props.confirm({
        title: "Stop recording?",
        message: "The recording is saved on the phone.",
        confirmLabel: "Stop recording",
        onConfirm: () => remote.connection.setRecording(false),
      });
    } else {
      props.confirm({
        title: "Start recording?",
        message: "Records the stream on the phone. It keeps going even if you close this page.",
        confirmLabel: "Start recording",
        confirmVariant: "accent",
        onConfirm: () => remote.connection.setRecording(true),
      });
    }
  }

  const buttonClass = () =>
    twMerge(
      "h-10 text-[13px] font-medium",
      mobile() ? "gap-1.5 px-0" : "px-3.5",
      stretch() && "flex-1 basis-0",
    );

  return (
    <div class={twMerge("flex", mobile() ? "gap-1.5" : "gap-2")}>
      <Button
        variant={remote.state.muted ? "selected" : "control"}
        class={buttonClass()}
        onClick={() => remote.connection.setMuted(!remote.state.muted)}
      >
        <Show when={!mobile()}>
          <Icon name={remote.state.muted ? "micOff" : "mic"} />
        </Show>
        {remote.state.muted ? "Muted" : "Mute"}
      </Button>
      <Button
        variant={remote.state.stealthMode ? "selected" : "control"}
        class={buttonClass()}
        onClick={() => remote.connection.setStealthMode(!remote.state.stealthMode)}
      >
        <Show when={!mobile()}>
          <Icon name="eyeOff" />
        </Show>
        Stealth
      </Button>
      <Button variant="control" class={buttonClass()} onClick={toggleRecording}>
        <div
          class={twMerge(
            "rounded-full border-2 border-danger",
            mobile() ? "size-[9px]" : "size-[11px]",
            remote.state.recording && "bg-danger",
          )}
        />
        {mobile() ? "Rec" : remote.state.recording ? "Recording" : "Record"}
      </Button>
      <Button
        variant={remote.state.streaming ? "danger" : "accent"}
        class={twMerge(
          "h-10 text-[13px]",
          mobile() ? "ml-3.5 flex-[1.3] basis-0" : "ml-6 px-4",
          props.layout === "tablet" && "flex-1 basis-0",
        )}
        onClick={toggleLive}
      >
        <Show when={!mobile() && remote.state.streaming}>
          <div class="size-2.5 rounded-[2px] bg-white" />
        </Show>
        {remote.state.streaming ? (mobile() ? "End" : "End stream") : "Go live"}
      </Button>
    </div>
  );
}

function compactStatus(remote: Remote): string {
  const status = remote.statusData();
  const parts: string[] = [];
  const bitrate = status?.topRight.bitrate?.message;
  if (bitrate) parts.push(bitrate.split(" (")[0]);
  const battery = status?.general?.batteryLevel;
  if (battery !== undefined) parts.push(`${battery}%`);
  return parts.join(" · ");
}

interface HeaderProps extends ActionsProps {
  tab: Tab;
  onSelectTab: (tab: Tab) => void;
  theme: ThemeChoice;
  onTheme: (choice: ThemeChoice) => void;
}

function Header(props: HeaderProps) {
  const dim = () => (props.remote.connected() ? "" : "pointer-events-none opacity-30");
  const brand = () => (
    <div class="flex items-center gap-2.5">
      <div class="text-[13px] font-semibold whitespace-nowrap">Moblin Remote</div>
      <ThemeButton theme={props.theme} onChange={props.onTheme} />
    </div>
  );
  return (
    <SolidSwitch>
      <Match when={props.layout === "desktop"}>
        <header class="flex h-[68px] items-center justify-between border-b border-divider bg-bar px-6">
          <div class="flex items-center gap-5">
            {brand()}
            <TabBar tab={props.tab} onSelect={props.onSelectTab} />
          </div>
          <LiveIndicator remote={props.remote} />
          <div class={dim()}>
            <Actions remote={props.remote} layout={props.layout} confirm={props.confirm} />
          </div>
        </header>
      </Match>
      <Match when={props.layout === "tablet"}>
        <header class="flex flex-col gap-3 border-b border-divider bg-bar px-6 py-3.5">
          <div class="flex items-center justify-between gap-4">
            <div class="flex items-center gap-5">
              {brand()}
              <TabBar tab={props.tab} onSelect={props.onSelectTab} />
            </div>
            <LiveIndicator remote={props.remote} />
          </div>
          <div class={dim()}>
            <Actions remote={props.remote} layout={props.layout} confirm={props.confirm} />
          </div>
        </header>
      </Match>
      <Match when={props.layout === "mobile"}>
        <header class="flex flex-col gap-2.5 border-b border-divider bg-bar px-4 py-3">
          <div class="flex items-center justify-between">
            <LiveIndicator remote={props.remote} compact />
            <div class="flex items-center gap-2.5">
              <div class="text-[11px] leading-[14px] text-muted">{compactStatus(props.remote)}</div>
              <ThemeButton theme={props.theme} onChange={props.onTheme} compact />
            </div>
          </div>
          <div class={dim()}>
            <Actions remote={props.remote} layout={props.layout} confirm={props.confirm} />
          </div>
        </header>
      </Match>
    </SolidSwitch>
  );
}

function formatAgo(milliseconds: number): string {
  const seconds = Math.max(0, Math.floor(milliseconds / 1000));
  const minutes = Math.floor(seconds / 60);
  if (minutes >= 60) {
    return `${Math.floor(minutes / 60)}:${String(minutes % 60).padStart(2, "0")}:${String(seconds % 60).padStart(2, "0")}`;
  }
  return `${minutes}:${String(seconds % 60).padStart(2, "0")}`;
}

function DisconnectedPanel(props: { remote: Remote }) {
  const [now, setNow] = createSignal(Date.now());
  const timerId = setInterval(() => setNow(Date.now()), 1000);
  onCleanup(() => clearInterval(timerId));
  const info = () => props.remote.reconnect();
  const subtitle = () => {
    const parts: string[] = [];
    const lostAt = info().lostAt;
    if (props.remote.everConnected() && lostAt !== undefined) {
      parts.push(`Lost connection ${formatAgo(now() - lostAt)} ago`);
    } else {
      parts.push("Can't reach Moblin");
    }
    const nextRetryAt = info().nextRetryAt;
    if (nextRetryAt === undefined) {
      parts.push("connecting…");
    } else {
      parts.push(`retrying in ${Math.max(1, Math.ceil((nextRetryAt - now()) / 1000))} s`);
    }
    return parts.join(" · ");
  };
  return (
    <div class="pointer-events-none fixed inset-x-0 top-[120px] z-40 flex justify-center px-4 desktop:top-[220px]">
      <div class="pointer-events-auto flex w-full max-w-[500px] flex-col gap-[18px] rounded-2xl border border-card-stroke bg-card p-5 shadow-[0_24px_64px_rgb(0_0_0/0.5)] tablet:p-7">
        <div class="flex items-center gap-3.5">
          <div class="flex size-10 shrink-0 items-center justify-center rounded-xl bg-danger-surface text-danger-fg">
            <Icon name="wifiOff" size={20} />
          </div>
          <div class="flex flex-col gap-1">
            <div class="text-[17px] leading-[22px] font-semibold">Phone not connected</div>
            <div class="text-[12px] leading-4 text-muted">{subtitle()}</div>
          </div>
        </div>
        <div class="text-[13px] leading-5 text-fg-3">
          The remote can't reach Moblin on your phone. Make sure Moblin is open, remote control is
          turned on and the phone has internet. Controls come back as soon as it reconnects.
        </div>
        <div class="flex items-center gap-2.5">
          <Button
            variant="accent"
            class="h-9 rounded-lg px-4 text-[13px]"
            disabled={info().nextRetryAt === undefined}
            onClick={() => props.remote.connection.retryNow()}
          >
            <Icon name="reload" size={14} stroke={2.2} />
            Retry now
          </Button>
          <div class="text-[12px] text-faint">Attempt {Math.max(1, info().attempt)}</div>
        </div>
      </div>
    </div>
  );
}

function App() {
  const remote = createRemote();
  const layout = createLayout();
  const [theme, setTheme] = createTheme();
  const [tab, setTab] = createSignal<Tab>(tabFromPath(window.location.pathname));
  const [dialog, setDialog] = createSignal<DialogConfig | null>(null);
  const [showDisconnected, setShowDisconnected] = createSignal(false);
  let disconnectedTimerId: ReturnType<typeof setTimeout> | undefined;

  function selectTab(newTab: Tab): void {
    if (newTab === tab()) return;
    window.history.pushState(null, "", tabs.find((item) => item.id === newTab)!.path);
    setTab(newTab);
    window.scrollTo(0, 0);
  }

  function onPopState(): void {
    setTab(tabFromPath(window.location.pathname));
  }

  onMount(() => {
    window.addEventListener("popstate", onPopState);
    onCleanup(() => window.removeEventListener("popstate", onPopState));
  });

  createEffect(() => {
    document.title = tabs.find((item) => item.id === tab())!.title;
  });

  createEffect(() => {
    clearTimeout(disconnectedTimerId);
    if (remote.connected()) {
      setShowDisconnected(false);
    } else if (remote.reconnect().attempt > 0) {
      setShowDisconnected(true);
    } else {
      disconnectedTimerId = setTimeout(() => setShowDisconnected(true), 2000);
    }
  });

  const pageProps: PageProps = { remote, layout, confirm: setDialog };

  const page = (): JSX.Element => (
    <SolidSwitch>
      <Match when={tab() === "control"}>
        <ControlPage {...pageProps} />
      </Match>
      <Match when={tab() === "scoreboard"}>
        <ScoreboardPage {...pageProps} />
      </Match>
      <Match when={tab() === "golf"}>
        <GolfPage {...pageProps} />
      </Match>
      <Match when={tab() === "recordings"}>
        <RecordingsPage {...pageProps} />
      </Match>
    </SolidSwitch>
  );

  return (
    <div class="flex min-h-dvh flex-col bg-page select-none">
      <Header
        remote={remote}
        layout={layout()}
        confirm={setDialog}
        tab={tab()}
        onSelectTab={selectTab}
        theme={theme()}
        onTheme={setTheme}
      />
      <main
        class={twMerge(
          "flex-1 px-3 pt-3 pb-8 tablet:px-6 tablet:pt-6",
          !remote.connected() && "pointer-events-none opacity-30",
        )}
      >
        {page()}
      </main>
      <Show when={layout() === "mobile"}>
        <BottomTabBar tab={tab()} onSelect={selectTab} />
      </Show>
      <Show when={showDisconnected()}>
        <DisconnectedPanel remote={remote} />
      </Show>
      <Dialog config={dialog} onClose={() => setDialog(null)} />
    </div>
  );
}

render(() => <App />, document.getElementById("app")!);
