import { createEffect, createSignal, For, Match, on, onMount, Show, Switch } from "solid-js";
import { Portal } from "solid-js/web";
import { twMerge } from "tailwind-merge";
import type { Layout, PageProps } from "./app.tsx";
import { Button, Card, EmptyState, Icon, Label, Select } from "./components.tsx";
import { copyText } from "./utils.ts";

interface Recording {
  name: string;
  size: string;
}

type SortOrder = "newest" | "oldest" | "largest" | "name";

const sortOptions: { value: SortOrder; label: string }[] = [
  { value: "newest", label: "Newest first" },
  { value: "oldest", label: "Oldest first" },
  { value: "largest", label: "Largest first" },
  { value: "name", label: "Name" },
];

const weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
const sizeUnits: Record<string, number> = { bytes: 1, kb: 1e3, mb: 1e6, gb: 1e9, tb: 1e12 };

function recordedAt(name: string): Date | undefined {
  const match = name.match(/(\d{4})-(\d{2})-(\d{2})_(\d{2})(\d{2})(\d{2})/);
  if (match === null) return undefined;
  const [year, month, day, hour, minute, second] = match.slice(1).map(Number);
  return new Date(year, month - 1, day, hour, minute, second);
}

function formatRecordedAt(date: Date | undefined): string {
  if (date === undefined) return "–";
  const time = `${String(date.getHours()).padStart(2, "0")}:${String(date.getMinutes()).padStart(2, "0")}`;
  const today = new Date();
  const yesterday = new Date(today.getFullYear(), today.getMonth(), today.getDate() - 1);
  if (date.toDateString() === today.toDateString()) return `Today, ${time}`;
  if (date.toDateString() === yesterday.toDateString()) return `Yesterday, ${time}`;
  const year = date.getFullYear() === today.getFullYear() ? "" : ` ${date.getFullYear()}`;
  return `${weekdays[date.getDay()]} ${date.getDate()} ${months[date.getMonth()]}${year}, ${time}`;
}

function sizeInBytes(size: string): number | undefined {
  const match = size.match(/([\d.,]+)\s*(bytes|[kmgt]b)/i);
  if (match === null) return undefined;
  return parseFloat(match[1].replace(",", ".")) * sizeUnits[match[2].toLowerCase()];
}

function formatTotalSize(bytes: number): string {
  if (bytes >= 1e9) return `${(bytes / 1e9).toFixed(1)} GB`;
  if (bytes >= 1e6) return `${Math.round(bytes / 1e6)} MB`;
  return `${Math.round(bytes / 1e3)} KB`;
}

function downloadUrl(filename: string): string {
  return new URL(`/recordings/${encodeURIComponent(filename)}`, window.location.origin).toString();
}

function thumbnailUrl(filename: string): string {
  return `/thumbnails/${encodeURIComponent(filename)}`;
}

function downloadFile(filename: string): void {
  const link = document.createElement("a");
  link.href = downloadUrl(filename);
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
}

async function deleteRecording(filename: string): Promise<void> {
  const response = await fetch(`/recordings/${encodeURIComponent(filename)}`, {
    method: "DELETE",
  });
  if (!response.ok) {
    throw new Error(`Failed to delete ${filename}: ${response.status}`);
  }
}

interface RowProps {
  recording: Recording;
  layout: Layout;
  onDelete: (recording: Recording) => void;
  onPreview: (src: string) => void;
}

function Thumbnail(props: { name: string; class: string; onPreview: (src: string) => void }) {
  const [failed, setFailed] = createSignal(false);
  return (
    <button
      type="button"
      class={twMerge("shrink-0 overflow-hidden rounded-md bg-well", props.class)}
      onClick={() => props.onPreview(thumbnailUrl(props.name))}
    >
      <Show
        when={!failed()}
        fallback={
          <div class="flex size-full items-center justify-center text-faint">
            <Icon name="video" size={18} stroke={1.8} />
          </div>
        }
      >
        <img
          src={thumbnailUrl(props.name)}
          alt=""
          loading="lazy"
          class="size-full object-cover"
          onError={() => setFailed(true)}
        />
      </Show>
    </button>
  );
}

function Actions(props: RowProps & { buttonClass: string }) {
  const [copyLabel, setCopyLabel] = createSignal("Copy link");

  async function copy(): Promise<void> {
    try {
      await copyText(downloadUrl(props.recording.name));
      setCopyLabel("Copied");
    } catch {
      setCopyLabel("Failed");
    }
    setTimeout(() => setCopyLabel("Copy link"), 1500);
  }

  return (
    <>
      <Button
        class={props.buttonClass}
        aria-label={`Copy download link for ${props.recording.name}`}
        onClick={copy}
      >
        {copyLabel()}
      </Button>
      <Button
        class={props.buttonClass}
        aria-label={`Download ${props.recording.name}`}
        onClick={() => downloadFile(props.recording.name)}
      >
        Download
      </Button>
      <Button
        class={twMerge(
          props.buttonClass,
          "text-danger-fg",
          props.layout !== "desktop" && "w-[72px] flex-none",
        )}
        aria-label={`Delete ${props.recording.name}`}
        onClick={() => props.onDelete(props.recording)}
      >
        Delete
      </Button>
    </>
  );
}

function TableRow(props: RowProps) {
  return (
    <div class="flex h-[76px] items-center gap-4 border-b border-divider px-3.5 last:border-b-0">
      <Thumbnail name={props.recording.name} class="h-[54px] w-24" onPreview={props.onPreview} />
      <div class="min-w-0 flex-1 truncate text-[13px]">{props.recording.name}</div>
      <div class="w-[170px] text-[12px] text-fg-2">
        {formatRecordedAt(recordedAt(props.recording.name))}
      </div>
      <div class="w-20 text-right text-[12px] text-fg-2">{props.recording.size}</div>
      <div class="flex w-[300px] justify-end gap-1.5">
        <Actions {...props} buttonClass="h-8 rounded-[7px] px-3 text-[12px]" />
      </div>
    </div>
  );
}

function CardRow(props: RowProps) {
  return (
    <div class="flex min-w-0 flex-col gap-2.5 rounded-xl border border-divider bg-sunken p-3">
      <div class="flex items-center gap-3">
        <Thumbnail
          name={props.recording.name}
          class="h-[50px] w-[88px]"
          onPreview={props.onPreview}
        />
        <div class="flex min-w-0 flex-1 flex-col gap-1">
          <div class="text-[13px]">{formatRecordedAt(recordedAt(props.recording.name))}</div>
          <div class="truncate text-[11px] text-muted">
            {props.recording.size} · {props.recording.name}
          </div>
        </div>
      </div>
      <div class="flex gap-1.5">
        <Actions {...props} buttonClass="h-9 flex-1 basis-0 rounded-lg text-[12px]" />
      </div>
    </div>
  );
}

export function RecordingsPage(props: PageProps) {
  const [recordings, setRecordings] = createSignal<Recording[]>([]);
  const [loading, setLoading] = createSignal(true);
  const [loadError, setLoadError] = createSignal(false);
  const [filter, setFilter] = createSignal("");
  const [sortOrder, setSortOrder] = createSignal<SortOrder>("newest");
  const [preview, setPreview] = createSignal<string | null>(null);

  async function loadRecordings(): Promise<void> {
    setLoadError(false);
    try {
      const response = await fetch("/recordings.json");
      setRecordings((await response.json()) as Recording[]);
    } catch {
      setLoadError(true);
    } finally {
      setLoading(false);
    }
  }

  onMount(loadRecordings);

  createEffect(
    on(
      () => props.remote.state.recording,
      (recording, wasRecording) => {
        if (wasRecording && !recording) setTimeout(loadRecordings, 1000);
      },
      { defer: true },
    ),
  );

  function askDelete(recording: Recording): void {
    props.confirm({
      title: "Delete recording?",
      message: `${recording.name} (${recording.size}) will be removed from the phone. This can't be undone.`,
      confirmLabel: "Delete",
      onConfirm: async () => {
        try {
          await deleteRecording(recording.name);
        } catch {
          return;
        }
        await loadRecordings();
      },
    });
  }

  function startRecording(): void {
    props.confirm({
      title: "Start recording?",
      message: "Records the stream on the phone. It keeps going even if you close this page.",
      confirmLabel: "Start recording",
      confirmVariant: "accent",
      onConfirm: () => props.remote.connection.setRecording(true),
    });
  }

  const totalSize = () => {
    const sizes = recordings().map((recording) => sizeInBytes(recording.size));
    if (sizes.length === 0 || sizes.some((size) => size === undefined)) return undefined;
    return formatTotalSize(sizes.reduce((sum: number, size) => sum + size!, 0));
  };

  const summary = () => {
    const count = recordings().length;
    const files = `${count} ${count === 1 ? "file" : "files"}`;
    return totalSize() !== undefined ? `${files} · ${totalSize()}` : files;
  };

  const shown = () => {
    const text = filter().trim().toLowerCase();
    const matching = recordings().filter(
      (recording) =>
        text === "" ||
        recording.name.toLowerCase().includes(text) ||
        formatRecordedAt(recordedAt(recording.name)).toLowerCase().includes(text),
    );
    const time = (recording: Recording) => recordedAt(recording.name)?.getTime() ?? 0;
    switch (sortOrder()) {
      case "newest":
        return matching.sort((a, b) => time(b) - time(a) || b.name.localeCompare(a.name));
      case "oldest":
        return matching.sort((a, b) => time(a) - time(b) || a.name.localeCompare(b.name));
      case "largest":
        return matching.sort((a, b) => (sizeInBytes(b.size) ?? 0) - (sizeInBytes(a.size) ?? 0));
      case "name":
        return matching.sort((a, b) => a.name.localeCompare(b.name));
    }
  };

  const rowProps = (recording: Recording): RowProps => ({
    recording,
    layout: props.layout(),
    onDelete: askDelete,
    onPreview: setPreview,
  });

  const mobile = () => props.layout() === "mobile";

  return (
    <>
      <Card class="gap-[18px] max-tablet:gap-3.5">
        <div class="flex flex-wrap items-center justify-between gap-3">
          <div class="flex items-center gap-4">
            <Label>Recordings</Label>
            <span class="text-[11px] text-faint">{summary()}</span>
          </div>
          <Show when={!mobile()}>
            <div
              class={twMerge(
                "flex items-center gap-2.5",
                recordings().length === 0 && "pointer-events-none opacity-40",
              )}
            >
              <label class="flex h-8 w-[260px] items-center gap-2.5 rounded-[7px] border border-control-stroke bg-control px-2.5 text-[12px] focus-within:border-accent">
                <Icon name="search" size={13} class="text-muted" />
                <input
                  type="text"
                  class="min-w-0 flex-1 bg-transparent outline-none"
                  placeholder="Filter by name or date"
                  value={filter()}
                  onInput={(event) => setFilter(event.currentTarget.value)}
                />
              </label>
              <Select
                class="h-8 rounded-[7px] text-[12px]"
                options={sortOptions}
                value={sortOrder()}
                onChange={(value) => setSortOrder(value as SortOrder)}
              />
            </div>
          </Show>
        </div>
        <Switch>
          <Match when={loading()}>
            <div class="py-16 text-center text-[12px] text-muted">Loading…</div>
          </Match>
          <Match when={loadError()}>
            <EmptyState
              icon="video"
              title="Couldn't load the recordings"
              message="The phone didn't answer. Check the connection and try again."
            >
              <Button variant="small" class="h-[34px] px-3.5" onClick={loadRecordings}>
                <Icon name="reload" size={12} />
                Try again
              </Button>
            </EmptyState>
          </Match>
          <Match when={recordings().length === 0}>
            <EmptyState
              icon="video"
              title="No recordings yet"
              message="Recordings made on the phone show up here. Start one with Record — it keeps going even if you close this page."
            >
              <Button variant="small" class="h-[34px] gap-2 px-3.5" onClick={startRecording}>
                <div class="size-2.5 rounded-full border-2 border-danger" />
                Start recording
              </Button>
            </EmptyState>
          </Match>
          <Match when={shown().length === 0}>
            <div class="py-16 text-center text-[12px] text-muted">
              No recordings match “{filter()}”.
            </div>
          </Match>
          <Match when={props.layout() === "desktop"}>
            <div class="flex flex-col overflow-hidden rounded-[10px] border border-divider">
              <div class="flex h-9 items-center gap-4 border-b border-divider bg-sunken px-3.5 text-[11px] tracking-[0.06em] text-muted">
                <div class="w-24" />
                <div class="flex-1">FILE</div>
                <div class="w-[170px]">RECORDED</div>
                <div class="w-20 text-right">SIZE</div>
                <div class="w-[300px]" />
              </div>
              <For each={shown()}>{(recording) => <TableRow {...rowProps(recording)} />}</For>
            </div>
          </Match>
          <Match when={true}>
            <div class="grid grid-cols-1 gap-2 tablet:grid-cols-2 tablet:gap-3.5">
              <For each={shown()}>{(recording) => <CardRow {...rowProps(recording)} />}</For>
            </div>
          </Match>
        </Switch>
      </Card>
      <Show when={preview()}>
        {(src) => (
          <Portal>
            <div
              class="fixed inset-0 z-50 flex items-center justify-center bg-black/90 p-4"
              onClick={() => setPreview(null)}
            >
              <img src={src()} alt="" class="max-h-full max-w-full object-contain" />
            </div>
          </Portal>
        )}
      </Show>
    </>
  );
}
