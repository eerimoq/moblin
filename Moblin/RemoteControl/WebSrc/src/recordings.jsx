import { createSignal, For, Show, onMount } from "solid-js";
import { render } from "solid-js/web";
import { showConfirm, confirmOk, confirmCancel } from "./utils.js";

const PREVIEW_CURSOR_MARGIN = 16;
const PREVIEW_FALLBACK_WIDTH = 320;
const PREVIEW_FALLBACK_HEIGHT = 240;

function hasHoverPreview() {
  return window.matchMedia("(hover: hover) and (pointer: fine)").matches;
}

function downloadUrl(filename) {
  return new URL(
    `/recordings/${encodeURIComponent(filename)}`,
    window.location.origin,
  ).toString();
}

async function copyText(text) {
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

function downloadFile(filename) {
  const link = document.createElement("a");
  link.href = downloadUrl(filename);
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
}

async function deleteRecording(filename) {
  const response = await fetch(`/recordings/${encodeURIComponent(filename)}`, {
    method: "DELETE",
  });
  if (!response.ok) {
    throw new Error(`Failed to delete ${filename}: ${response.status}`);
  }
}

function HoverPreview() {
  let previewEl;

  function positionPreview(event) {
    const vw = window.innerWidth;
    const vh = window.innerHeight;
    const pw = previewEl.offsetWidth || PREVIEW_FALLBACK_WIDTH;
    const ph = previewEl.offsetHeight || PREVIEW_FALLBACK_HEIGHT;

    let x = event.clientX + PREVIEW_CURSOR_MARGIN;
    let y = event.clientY + PREVIEW_CURSOR_MARGIN;

    if (x + pw > vw - PREVIEW_CURSOR_MARGIN) {
      x = event.clientX - pw - PREVIEW_CURSOR_MARGIN;
    }
    if (y + ph > vh - PREVIEW_CURSOR_MARGIN) {
      y = vh - ph - PREVIEW_CURSOR_MARGIN;
    }
    if (x < PREVIEW_CURSOR_MARGIN) x = PREVIEW_CURSOR_MARGIN;
    if (y < PREVIEW_CURSOR_MARGIN) y = PREVIEW_CURSOR_MARGIN;

    previewEl.style.left = `${x}px`;
    previewEl.style.top = `${y}px`;
  }

  return {
    show(src, event) {
      const img = previewEl.querySelector("img");
      img.src = src;
      previewEl.style.display = "block";
      positionPreview(event);
    },
    move(event) {
      if (previewEl.style.display === "block") positionPreview(event);
    },
    hide() {
      previewEl.style.display = "none";
    },
    element: (
      <div
        ref={previewEl}
        class="thumbnail-preview"
        style={{ display: "none" }}
      >
        <img />
      </div>
    ),
  };
}

function RecordingRow({
  recording,
  onDelete,
  onMobilePreview,
  hoverPreview,
}) {
  const [copyLabel, setCopyLabel] = createSignal("Copy link");
  const src = `/thumbnails/${encodeURIComponent(recording.name)}`;

  async function handleCopy(e) {
    e.preventDefault();
    e.stopPropagation();
    try {
      await copyText(downloadUrl(recording.name));
      setCopyLabel("Copied");
    } catch {
      setCopyLabel("Failed");
    }
    setTimeout(() => setCopyLabel("Copy link"), 1500);
  }

  function handleDownload(e) {
    e.preventDefault();
    e.stopPropagation();
    downloadFile(recording.name);
  }

  function handleDelete(e) {
    e.preventDefault();
    e.stopPropagation();
    onDelete(recording.name);
  }

  function handleThumbnailClick(e) {
    if (hasHoverPreview()) return;
    e.preventDefault();
    e.stopPropagation();
    onMobilePreview(src);
  }

  return (
    <div class="recording-row">
      <div class="recording-header">
        <img
          class="recording-thumbnail"
          src={src}
          alt=""
          onMouseEnter={
            hasHoverPreview() ? (e) => hoverPreview.show(src, e) : undefined
          }
          onMouseMove={
            hasHoverPreview() ? (e) => hoverPreview.move(e) : undefined
          }
          onMouseLeave={hasHoverPreview() ? () => hoverPreview.hide() : undefined}
          onClick={handleThumbnailClick}
        />
        <span class="recording-name">{recording.name}</span>
      </div>
      <div class="recording-footer">
        <span class="recording-size">{recording.size}</span>
        <button
          type="button"
          class="recording-share-button"
          aria-label={`Copy download link for ${recording.name}`}
          onClick={handleCopy}
        >
          {copyLabel()}
        </button>
        <button
          type="button"
          class="recording-download-button"
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
  const [recordings, setRecordings] = createSignal([]);
  const [loading, setLoading] = createSignal(true);
  const [loadError, setLoadError] = createSignal(false);
  const [mobilePreviewSrc, setMobilePreviewSrc] = createSignal(null);
  const [confirmMessage, setConfirmMessage] = createSignal("");
  const [confirmOpen, setConfirmOpen] = createSignal(false);

  const hoverPreview = HoverPreview();

  async function loadRecordings() {
    setLoading(true);
    setLoadError(false);
    try {
      const response = await fetch("/recordings.json");
      const data = await response.json();
      setRecordings(data);
    } catch {
      setLoadError(true);
    } finally {
      setLoading(false);
    }
  }

  async function handleDelete(filename) {
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

  return (
    <div class="max-w-3xl mx-auto space-y-2">
      <h1 class="text-2xl font-bold text-center">Moblin Recordings</h1>

      <div class="pb-1 text-center space-x-4">
        <a href="./" class="text-indigo-400 hover:text-indigo-300 text-sm">
          Remote Control
        </a>
        <a
          href="https://github.com/eerimoq/moblin"
          target="_blank"
          class="text-indigo-400 hover:text-indigo-300 text-sm"
        >
          Github
        </a>
      </div>

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

      {hoverPreview.element}

      <Show when={confirmOpen()}>
        <dialog
          open
          class="backdrop:bg-black/60 rounded-xl p-0"
          style={{ position: "fixed", top: "50%", left: "50%", transform: "translate(-50%, -50%)", margin: 0 }}
        >
          <form method="dialog" class="bg-zinc-900 text-zinc-100">
            <div class="p-2">
              <p class="text-zinc-300">{confirmMessage()}</p>
            </div>
            <div class="bg-zinc-800/60 px-4 py-3 sm:px-5 flex items-center justify-end gap-2">
              <button
                type="button"
                class="px-3 py-1.5 rounded-md border border-zinc-700 text-red-400 hover:bg-zinc-800 cursor-pointer"
                onClick={confirmOk}
              >
                Delete
              </button>
              <button
                type="button"
                class="px-3 py-1.5 rounded-md border border-zinc-700 text-zinc-300 hover:bg-zinc-800 cursor-pointer"
                onClick={confirmCancel}
              >
                Cancel
              </button>
            </div>
          </form>
        </dialog>
      </Show>

      <Show when={mobilePreviewSrc() !== null}>
        <div
          class="mobile-preview"
          aria-hidden="false"
          onClick={() => setMobilePreviewSrc(null)}
        >
          <div class="mobile-preview-backdrop">
            <img
              class="mobile-preview-image"
              src={mobilePreviewSrc()}
              alt=""
            />
          </div>
        </div>
      </Show>
    </div>
  );
}

render(() => <App />, document.getElementById("app"));
