const selectedFiles = new Set();
let previewEl = null;
let confirmComplete = null;
let confirmResult = false;

const PREVIEW_CURSOR_MARGIN = 16;
const PREVIEW_FALLBACK_WIDTH = 320;
const PREVIEW_FALLBACK_HEIGHT = 240;

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

function updateSelectionUI() {
  const downloadButton = document.getElementById("downloadSelected");
  const deleteButton = document.getElementById("deleteSelected");
  const selectionCount = document.getElementById("selectionCount");
  downloadButton.disabled = selectedFiles.size === 0;
  deleteButton.disabled = selectedFiles.size === 0;
  if (selectedFiles.size > 0) {
    selectionCount.textContent = `${selectedFiles.size} selected`;
  } else {
    selectionCount.textContent = "";
  }
  const selectAll = document.getElementById("selectAll");
  const checkboxes = document.querySelectorAll(".recording-checkbox");
  if (checkboxes.length === 0) {
    selectAll.checked = false;
    selectAll.indeterminate = false;
  } else if (selectedFiles.size === checkboxes.length) {
    selectAll.checked = true;
    selectAll.indeterminate = false;
  } else if (selectedFiles.size > 0) {
    selectAll.checked = false;
    selectAll.indeterminate = true;
  } else {
    selectAll.checked = false;
    selectAll.indeterminate = false;
  }
}

function toggleFile(filename, checked) {
  if (checked) {
    selectedFiles.add(filename);
  } else {
    selectedFiles.delete(filename);
  }
  updateSelectionUI();
}

function toggleAll(checked) {
  const checkboxes = document.querySelectorAll(".recording-checkbox");
  checkboxes.forEach((cb) => {
    cb.checked = checked;
    toggleFile(cb.value, checked);
  });
}

function createRecordingRow(recording) {
  const row = document.createElement("div");
  row.className = "recording-row";

  const label = document.createElement("label");

  const checkbox = document.createElement("input");
  checkbox.type = "checkbox";
  checkbox.className = "recording-checkbox";
  checkbox.value = recording.name;
  checkbox.addEventListener("change", (e) => {
    toggleFile(recording.name, e.target.checked);
  });

  const thumbnail = document.createElement("img");
  thumbnail.className = "recording-thumbnail";
  thumbnail.src = `/thumbnails/${encodeURIComponent(recording.name)}`;
  thumbnail.alt = "";
  thumbnail.addEventListener("mouseenter", (e) => showPreview(thumbnail.src, e));
  thumbnail.addEventListener("mousemove", (e) => {
    if (previewEl && previewEl.style.display === "block") {
      positionPreview(previewEl, e);
    }
  });
  thumbnail.addEventListener("mouseleave", hidePreview);

  const name = document.createElement("span");
  name.className = "recording-name";
  name.textContent = recording.name;

  label.appendChild(checkbox);
  label.appendChild(thumbnail);
  label.appendChild(name);
  row.appendChild(label);

  const size = document.createElement("span");
  size.className = "recording-size";
  size.textContent = recording.size;
  row.appendChild(size);

  const shareButton = document.createElement("button");
  shareButton.type = "button";
  shareButton.className = "recording-share-button";
  shareButton.textContent = "Copy link";
  shareButton.setAttribute("aria-label", `Copy download link for ${recording.name}`);
  shareButton.addEventListener("click", async () => {
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
  row.appendChild(shareButton);

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

function downloadSelected() {
  let delay = 0;
  for (const filename of selectedFiles) {
    setTimeout(() => downloadFile(filename), delay);
    delay += 200;
  }
}

async function confirm(message) {
  document.getElementById("confirm-message").textContent = message;
  const dialog = document.getElementById("confirm");
  dialog.showModal();
  await new Promise((resolve) => {
    confirmComplete = (result) => {
      confirmResult = result;
      resolve();
    };
  });
  dialog.close();
  return confirmResult;
}

function confirmOk() {
  confirmComplete(true);
}

function confirmCancel() {
  confirmComplete(false);
}

async function deleteRecording(filename) {
  const response = await fetch(`/recordings/${encodeURIComponent(filename)}`, { method: "DELETE" });
  if (!response.ok) {
    throw new Error(`Failed to delete ${filename}: ${response.status}`);
  }
}

async function deleteSelected() {
  const count = selectedFiles.size;
  const noun = count === 1 ? "recording" : "recordings";
  if (!(await confirm(`Delete ${count} selected ${noun}? This cannot be undone.`))) {
    return;
  }
  const filenames = [...selectedFiles];
  const results = await Promise.allSettled(filenames.map((filename) => deleteRecording(filename)));
  results.forEach((result, index) => {
    if (result.status === "fulfilled") {
      selectedFiles.delete(filenames[index]);
    }
  });
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
  updateSelectionUI();
}

window.addEventListener("DOMContentLoaded", () => {
  document.getElementById("selectAll").addEventListener("change", (e) => {
    toggleAll(e.target.checked);
  });
  document.getElementById("downloadSelected").addEventListener("click", downloadSelected);
  document.getElementById("deleteSelected").addEventListener("click", deleteSelected);
  document.getElementById("confirm-ok").addEventListener("click", confirmOk);
  document.getElementById("confirm-cancel").addEventListener("click", confirmCancel);
  loadRecordings();
});
