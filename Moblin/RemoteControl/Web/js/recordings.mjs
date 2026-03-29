const selectedFiles = new Set();

function updateSelectionUI() {
  const downloadButton = document.getElementById("downloadSelected");
  const selectionCount = document.getElementById("selectionCount");
  downloadButton.disabled = selectedFiles.size === 0;
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

  return row;
}

function downloadFile(filename) {
  const link = document.createElement("a");
  link.href = `/recordings/${encodeURIComponent(filename)}`;
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
      return;
    }

    for (const recording of recordings) {
      list.appendChild(createRecordingRow(recording));
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
  loadRecordings();
});
