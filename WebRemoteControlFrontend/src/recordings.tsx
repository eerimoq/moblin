import { createSignal, For, Show, onMount } from "solid-js";
import { render } from "solid-js/web";
import { showConfirm, confirmOk, confirmCancel } from "./utils.ts";
import { BasicLinks, ConfirmDialog, Title } from "./components.tsx";

interface Recording {
  name: string;
  size: string;
}

interface HoverPreviewHandle {
  show(src: string, event: MouseEvent): void;
  move(event: MouseEvent): void;
  hide(): void;
  element: HTMLDivElement;
}

const PREVIEW_CURSOR_MARGIN = 16;
const PREVIEW_FALLBACK_WIDTH = 320;
const PREVIEW_FALLBACK_HEIGHT = 240;

function hasHoverPreview(): boolean {
  return window.matchMedia("(hover: hover) and (pointer: fine)").matches;
}

function downloadUrl(filename: string): string {
  return new URL(`/recordings/${encodeURIComponent(filename)}`, window.location.origin).toString();
}

async function copyText(text: string): Promise<void> {
  if (navigator.clipboard && window.isSecureContext) {
    await navigator.clipboard.writeText(text);
    return;
  }
  const textArea = document.createElement("textarea");
  textArea.value = text;
  textArea.setAttribute("readonly", "");
  textArea.style.position = "fixed";
  textArea.style.top = "-1000px";
  textArea.style.left = "-1000px";
  document.body.appendChild(textArea);
  textArea.focus();
  textArea.select();
  textArea.setSelectionRange(0, text.length);
  const success = document.execCommand("copy");
  document.body.removeChild(textArea);
  if (!success) throw new Error("Copy failed");
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

function HoverPreview(): HoverPreviewHandle {
  let previewEl!: HTMLDivElement;

  function positionPreview(event: MouseEvent): void {
    const windowWidth = window.innerWidth;
    const windowHeight = window.innerHeight;
    const previewWidth = previewEl.offsetWidth || PREVIEW_FALLBACK_WIDTH;
    const previewHeight = previewEl.offsetHeight || PREVIEW_FALLBACK_HEIGHT;
    let xPos = event.clientX + PREVIEW_CURSOR_MARGIN;
    let yPos = event.clientY + PREVIEW_CURSOR_MARGIN;
    if (xPos + previewWidth > windowWidth - PREVIEW_CURSOR_MARGIN) {
      xPos = event.clientX - previewWidth - PREVIEW_CURSOR_MARGIN;
    }
    if (yPos + previewHeight > windowHeight - PREVIEW_CURSOR_MARGIN) {
      yPos = windowHeight - previewHeight - PREVIEW_CURSOR_MARGIN;
    }
    if (xPos < PREVIEW_CURSOR_MARGIN) xPos = PREVIEW_CURSOR_MARGIN;
    if (yPos < PREVIEW_CURSOR_MARGIN) yPos = PREVIEW_CURSOR_MARGIN;
    previewEl.style.left = `${xPos}px`;
    previewEl.style.top = `${yPos}px`;
  }

  return {
    show(src: string, event: MouseEvent): void {
      const img = previewEl.querySelector("img");
      img!.src = src;
      previewEl.style.display = "block";
      positionPreview(event);
    },
    move(event: MouseEvent): void {
      if (previewEl.style.display === "block") positionPreview(event);
    },
    hide(): void {
      previewEl.style.display = "none";
    },
    element: (
      <div
        ref={(el: HTMLDivElement) => {
          previewEl = el;
        }}
        class="thumbnail-preview"
        style={{ display: "none" }}
      >
        <img />
      </div>
    ) as HTMLDivElement,
  };
}

interface RecordingRowProps {
  recording: Recording;
  onDelete: (name: string) => void;
  onMobilePreview: (src: string) => void;
  hoverPreview: HoverPreviewHandle;
}

function RecordingRow({ recording, onDelete, onMobilePreview, hoverPreview }: RecordingRowProps) {
  const [copyLabel, setCopyLabel] = createSignal("Copy link");
  const src = `/thumbnails/${encodeURIComponent(recording.name)}`;

  async function handleCopy(event: MouseEvent): Promise<void> {
    event.preventDefault();
    event.stopPropagation();
    try {
      await copyText(downloadUrl(recording.name));
      setCopyLabel("Copied");
    } catch {
      setCopyLabel("Failed");
    }
    setTimeout(() => setCopyLabel("Copy link"), 1500);
  }

  function handleDownload(event: MouseEvent): void {
    event.preventDefault();
    event.stopPropagation();
    downloadFile(recording.name);
  }

  function handleDelete(event: MouseEvent): void {
    event.preventDefault();
    event.stopPropagation();
    onDelete(recording.name);
  }

  function handleThumbnailClick(event: MouseEvent): void {
    if (hasHoverPreview()) return;
    event.preventDefault();
    event.stopPropagation();
    onMobilePreview(src);
  }

  return (
    <div class="recording">
      <div class="recording-header">
        <img
          class="recording-thumbnail"
          src={src}
          alt=""
          onMouseEnter={hasHoverPreview() ? (event) => hoverPreview.show(src, event) : undefined}
          onMouseMove={hasHoverPreview() ? (event) => hoverPreview.move(event) : undefined}
          onMouseLeave={hasHoverPreview() ? () => hoverPreview.hide() : undefined}
          onClick={handleThumbnailClick}
        />
        <span class="recording-name">{recording.name}</span>
      </div>
      <div class="recording-footer">
        <span class="recording-size">{recording.size}</span>
        <button
          type="button"
          class="recording-button"
          aria-label={`Copy download link for ${recording.name}`}
          onClick={handleCopy}
        >
          {copyLabel()}
        </button>
        <button
          type="button"
          class="recording-button"
          aria-label={`Download ${recording.name}`}
          onClick={handleDownload}
        >
          Download
        </button>
        <button
          type="button"
          class="recording-delete-button"
          aria-label={`Delete ${recording.name}`}
          onClick={handleDelete}
        >
          Delete
        </button>
      </div>
    </div>
  );
}

function App() {
  const [recordings, setRecordings] = createSignal<Recording[]>([]);
  const [loading, setLoading] = createSignal(true);
  const [loadError, setLoadError] = createSignal(false);
  const [mobilePreviewSrc, setMobilePreviewSrc] = createSignal<string | null>(null);
  const [confirmMessage, setConfirmMessage] = createSignal("");
  const [confirmOpen, setConfirmOpen] = createSignal(false);
  const hoverPreview = HoverPreview();

  async function loadRecordings(): Promise<void> {
    setLoading(true);
    setLoadError(false);
    try {
      const response = await fetch("/recordings.json");
      const data = (await response.json()) as Recording[];
      setRecordings(data);
    } catch {
      setLoadError(true);
    } finally {
      setLoading(false);
    }
  }

  async function handleDelete(filename: string): Promise<void> {
    const ok = await showConfirm(
      `Delete "${filename}"? This cannot be undone.`,
      setConfirmMessage,
      setConfirmOpen,
    );
    if (!ok) return;
    try {
      await deleteRecording(filename);
    } catch {
      return;
    }
    await loadRecordings();
  }

  onMount(loadRecordings);

  function Recordings() {
    return (
      <div class="bg-zinc-900 border border-zinc-700 rounded-lg p-2">
        <Show when={loading()}>
          <div class="text-sm text-zinc-500 text-center">
            {loadError() ? "Failed to load recordings." : "Loading..."}
          </div>
        </Show>
        <Show when={!loading() && recordings().length === 0}>
          <div class="text-sm text-zinc-500 text-center">No recordings found.</div>
        </Show>
        <For each={recordings()}>
          {(recording) => (
            <RecordingRow
              recording={recording}
              onDelete={handleDelete}
              onMobilePreview={setMobilePreviewSrc}
              hoverPreview={hoverPreview}
            />
          )}
        </For>
      </div>
    );
  }

  function MobliePreview() {
    return (
      <Show when={mobilePreviewSrc() !== null}>
        <div class="mobile-preview" aria-hidden="false" onClick={() => setMobilePreviewSrc(null)}>
          <div class="mobile-preview-backdrop">
            <img class="mobile-preview-image" src={mobilePreviewSrc() ?? undefined} alt="" />
          </div>
        </div>
      </Show>
    );
  }

  return (
    <div class="max-w-3xl mx-auto space-y-2">
      <Title title="Moblin Recordings"/>
      <BasicLinks />
      <Recordings />
      {hoverPreview.element}
      <ConfirmDialog
        open={confirmOpen}
        message={confirmMessage}
        onOk={confirmOk}
        onCancel={confirmCancel}
        okTextClass="text-red-400"
        okLabel="Delete"
      />
      <MobliePreview />
    </div>
  );
}

render(() => <App />, document.getElementById("app")!);
