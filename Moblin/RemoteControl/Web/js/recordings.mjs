import { confirm, confirmOk, confirmCancel } from "./utils.mjs";

let previewEl = null;

const PREVIEW_CURSOR_MARGIN = 16;
const PREVIEW_FALLBACK_WIDTH = 320;
const PREVIEW_FALLBACK_HEIGHT = 240;
let mobilePreviewVisible = false;

function hasHoverPreview() {
  return window.matchMedia("(hover: hover) and (pointer: fine)").matches;
}

function getOrCreatePreview() {
  if (!previewEl) {
    previewEl = document.createElement("div");
    previewEl.className = "thumbnail-preview";
    const img = document.createElement("img");
    previewEl.appendChild(img);
    document.body.appendChild(previewEl);
  }
  return previewEl;
}

function showPreview(src, event) {
  const preview = getOrCreatePreview();
  const img = preview.querySelector("img");
  img.src = src;
  preview.style.display = "block";
  positionPreview(preview, event);
}

function positionPreview(preview, event) {
  const vw = window.innerWidth;
  const vh = window.innerHeight;
  const pw = preview.offsetWidth || PREVIEW_FALLBACK_WIDTH;
  const ph = preview.offsetHeight || PREVIEW_FALLBACK_HEIGHT;

  let x = event.clientX + PREVIEW_CURSOR_MARGIN;
  let y = event.clientY + PREVIEW_CURSOR_MARGIN;

  if (x + pw > vw - PREVIEW_CURSOR_MARGIN) {
    x = event.clientX - pw - PREVIEW_CURSOR_MARGIN;
  }
  if (y + ph > vh - PREVIEW_CURSOR_MARGIN) {
    y = vh - ph - PREVIEW_CURSOR_MARGIN;
  }
  if (x < PREVIEW_CURSOR_MARGIN) {
    x = PREVIEW_CURSOR_MARGIN;
  }
  if (y < PREVIEW_CURSOR_MARGIN) {
    y = PREVIEW_CURSOR_MARGIN;
  }

  preview.style.left = `${x}px`;
  preview.style.top = `${y}px`;
}

function hidePreview() {
  if (previewEl) {
    previewEl.style.display = "none";
  }
}

function openMobilePreview(src) {
  const preview = document.getElementById("mobilePreview");
  const image = document.getElementById("mobilePreviewImage");
  image.src = src;
  preview.classList.remove("hidden");
  preview.setAttribute("aria-hidden", "false");
  document.body.classList.add("mobile-preview-open");
  mobilePreviewVisible = true;
}

function closeMobilePreview() {
  const preview = document.getElementById("mobilePreview");
  const image = document.getElementById("mobilePreviewImage");
  preview.classList.add("hidden");
  preview.setAttribute("aria-hidden", "true");
  image.removeAttribute("src");
  document.body.classList.remove("mobile-preview-open");
  mobilePreviewVisible = false;
}

function toggleMobilePreview(src) {
  if (mobilePreviewVisible) {
    closeMobilePreview();
  } else {
    openMobilePreview(src);
  }
}

function createRecordingRow(recording) {
  const row = document.createElement("div");
  row.className = "recording-row";

  const main = document.createElement("div");
  main.className = "recording-header";

  const thumbnail = document.createElement("img");
  thumbnail.className = "recording-thumbnail";
  thumbnail.src = `/thumbnails/${encodeURIComponent(recording.name)}`;
  thumbnail.alt = "";
  if (hasHoverPreview()) {
    thumbnail.addEventListener("mouseenter", (e) => showPreview(thumbnail.src, e));
    thumbnail.addEventListener("mousemove", (e) => {
      if (previewEl && previewEl.style.display === "block") {
        positionPreview(previewEl, e);
      }
    });
    thumbnail.addEventListener("mouseleave", hidePreview);
  }
  thumbnail.addEventListener("click", (e) => {
    if (hasHoverPreview()) {
      return;
    }
    e.preventDefault();
    e.stopPropagation();
    toggleMobilePreview(thumbnail.src);
  });

  const name = document.createElement("span");
  name.className = "recording-name";
  name.textContent = recording.name;

  const size = document.createElement("span");
  size.className = "recording-size";
  size.textContent = recording.size;

  const shareButton = document.createElement("button");
  shareButton.type = "button";
  shareButton.className = "recording-share-button";
  shareButton.textContent = "Copy link";
  shareButton.setAttribute("aria-label", `Copy download link for ${recording.name}`);
  shareButton.addEventListener("click", async (e) => {
    e.preventDefault();
    e.stopPropagation();
    const originalText = shareButton.textContent;
    try {
      await copyText(downloadUrl(recording.name));
      shareButton.textContent = "Copied";
    } catch {
      shareButton.textContent = "Failed";
    }
    setTimeout(() => {
      shareButton.textContent = originalText;
    }, 1500);
  });

  const downloadButton = document.createElement("button");
  downloadButton.type = "button";
  downloadButton.className = "recording-download-button";
  downloadButton.textContent = "Download";
  downloadButton.setAttribute("aria-label", `Download ${recording.name}`);
  downloadButton.addEventListener("click", (e) => {
    e.preventDefault();
    e.stopPropagation();
    downloadFile(recording.name);
  });

  const deleteButton = document.createElement("button");
  deleteButton.type = "button";
  deleteButton.className = "recording-delete-button";
  deleteButton.textContent = "Delete";
  deleteButton.setAttribute("aria-label", `Delete ${recording.name}`);
  deleteButton.addEventListener("click", async (e) => {
    e.preventDefault();
    e.stopPropagation();
    await deleteAndReload(recording.name);
  });

  const footer = document.createElement("div");
  footer.className = "recording-footer";

  footer.appendChild(size);
  footer.appendChild(shareButton);
  footer.appendChild(downloadButton);
  footer.appendChild(deleteButton);

  main.appendChild(thumbnail);
  main.appendChild(name);
  row.appendChild(main);
  row.appendChild(footer);

  return row;
}

function downloadUrl(filename) {
  return new URL(`/recordings/${encodeURIComponent(filename)}`, window.location.origin).toString();
}

async function copyText(text) {
  if (navigator.clipboard && window.isSecureContext) {
    await navigator.clipboard.writeText(text);
    return;
  }
  fallbackCopyText(text);
}

function fallbackCopyText(text) {
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
  if (!success) {
    throw new Error("Copy failed");
  }
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
  const response = await fetch(`/recordings/${encodeURIComponent(filename)}`, { method: "DELETE" });
  if (!response.ok) {
    throw new Error(`Failed to delete ${filename}: ${response.status}`);
  }
}

async function deleteAndReload(filename) {
  if (!(await confirm(`Delete "${filename}"? This cannot be undone.`))) {
    return;
  }
  try {
    await deleteRecording(filename);
  } catch {
    return;
  }
  const list = document.getElementById("recordingsList");
  list.innerHTML = "";
  const emptyMessage = document.getElementById("emptyMessage");
  emptyMessage.classList.add("hidden");
  const loadingMessage = document.getElementById("loadingMessage");
  loadingMessage.textContent = "Loading...";
  loadingMessage.classList.remove("hidden");
  await loadRecordings();
}

async function loadRecordings() {
  const list = document.getElementById("recordingsList");
  const emptyMessage = document.getElementById("emptyMessage");
  const loadingMessage = document.getElementById("loadingMessage");

  try {
    const response = await fetch("/recordings.json");
    const recordings = await response.json();
    loadingMessage.classList.add("hidden");

    if (recordings.length === 0) {
      emptyMessage.classList.remove("hidden");
    } else {
      for (const recording of recordings) {
        list.appendChild(createRecordingRow(recording));
      }
    }
  } catch {
    loadingMessage.textContent = "Failed to load recordings.";
  }
}

window.addEventListener("DOMContentLoaded", () => {
  document.getElementById("confirm-ok").addEventListener("click", confirmOk);
  document.getElementById("confirm-cancel").addEventListener("click", confirmCancel);
  document.getElementById("mobilePreviewBackdrop").addEventListener("click", closeMobilePreview);
  loadRecordings();
});
