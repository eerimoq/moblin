<svelte:head>
  <title>Moblin Recordings</title>
  <link rel="icon" type="image/x-icon" href="favicon.ico" />
  <link rel="stylesheet" href="css/app.css" />
  <link rel="stylesheet" href="css/common.css" />
  <link rel="stylesheet" href="css/recordings.css" />
</svelte:head>

<script>
  const PREVIEW_CURSOR_MARGIN = 16;
  const PREVIEW_FALLBACK_WIDTH = 320;
  const PREVIEW_FALLBACK_HEIGHT = 240;

  let recordings = $state([]);
  let loading = $state(true);
  let loadError = $state(false);
  let mobilePreviewSrc = $state(null);
  let confirmMessage = $state("");
  let confirmResolve = $state(null);

  // Preview state for desktop hover
  let previewSrc = $state(null);
  let previewLeft = $state(0);
  let previewTop = $state(0);

  function hasHoverPreview() {
    return window.matchMedia("(hover: hover) and (pointer: fine)").matches;
  }

  function downloadUrl(filename) {
    return new URL(`/recordings/${encodeURIComponent(filename)}`, window.location.origin).toString();
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
    if (!response.ok) throw new Error(`Failed to delete ${filename}: ${response.status}`);
  }

  async function showConfirm(message) {
    confirmMessage = message;
    return new Promise((resolve) => {
      confirmResolve = resolve;
      document.getElementById("confirm").showModal();
    });
  }

  function handleConfirmOk() {
    document.getElementById("confirm").close();
    if (confirmResolve) {
      confirmResolve(true);
      confirmResolve = null;
    }
  }

  function handleConfirmCancel() {
    document.getElementById("confirm").close();
    if (confirmResolve) {
      confirmResolve(false);
      confirmResolve = null;
    }
  }

  async function handleDelete(filename) {
    if (!(await showConfirm(`Delete "${filename}"? This cannot be undone.`))) return;
    try {
      await deleteRecording(filename);
      recordings = recordings.filter((r) => r.name !== filename);
    } catch {
      // silently ignore
    }
  }

  async function handleCopyLink(recording) {
    recording._copyStatus = "Copied";
    recordings = [...recordings];
    try {
      await copyText(downloadUrl(recording.name));
    } catch {
      recording._copyStatus = "Failed";
      recordings = [...recordings];
    }
    setTimeout(() => {
      recording._copyStatus = null;
      recordings = [...recordings];
    }, 1500);
  }

  function positionPreview(event, previewEl) {
    const vw = window.innerWidth;
    const vh = window.innerHeight;
    const pw = previewEl?.offsetWidth || PREVIEW_FALLBACK_WIDTH;
    const ph = previewEl?.offsetHeight || PREVIEW_FALLBACK_HEIGHT;
    let x = event.clientX + PREVIEW_CURSOR_MARGIN;
    let y = event.clientY + PREVIEW_CURSOR_MARGIN;
    if (x + pw > vw - PREVIEW_CURSOR_MARGIN) x = event.clientX - pw - PREVIEW_CURSOR_MARGIN;
    if (y + ph > vh - PREVIEW_CURSOR_MARGIN) y = vh - ph - PREVIEW_CURSOR_MARGIN;
    if (x < PREVIEW_CURSOR_MARGIN) x = PREVIEW_CURSOR_MARGIN;
    if (y < PREVIEW_CURSOR_MARGIN) y = PREVIEW_CURSOR_MARGIN;
    previewLeft = x;
    previewTop = y;
  }

  let previewEl = $state(null);

  async function loadRecordings() {
    loading = true;
    loadError = false;
    try {
      const response = await fetch("/recordings.json");
      const data = await response.json();
      recordings = data.map((r) => ({ ...r, _copyStatus: null }));
      loading = false;
    } catch {
      loading = false;
      loadError = true;
    }
  }

  loadRecordings();
</script>

<div class="bg-zinc-950 text-zinc-100 font-sans p-2">
  <div class="max-w-3xl mx-auto space-y-2">
    <h1 class="text-2xl font-bold text-center">Moblin Recordings</h1>

    <div class="pb-1 text-center space-x-4">
      <a href="./" class="text-indigo-400 hover:text-indigo-300 text-sm">Remote Control</a>
      <a
        href="https://github.com/eerimoq/moblin"
        target="_blank"
        class="text-indigo-400 hover:text-indigo-300 text-sm"
      >
        Github
      </a>
    </div>

    <div class="bg-zinc-900 border border-zinc-700 rounded-lg p-2">
      {#if loading}
        <div class="text-sm text-zinc-500 text-center">Loading...</div>
      {:else if loadError}
        <div class="text-sm text-zinc-500 text-center">Failed to load recordings.</div>
      {:else if recordings.length === 0}
        <div class="text-sm text-zinc-500 text-center">No recordings found.</div>
      {:else}
        <div class="space-y-1">
          {#each recordings as recording (recording.name)}
            {@const thumbSrc = `/thumbnails/${encodeURIComponent(recording.name)}`}
            <div class="recording-row">
              <div class="recording-header">
                <!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
                <img
                  class="recording-thumbnail"
                  src={thumbSrc}
                  alt=""
                  onmouseenter={hasHoverPreview()
                    ? (e) => {
                        previewSrc = thumbSrc;
                        positionPreview(e, previewEl);
                      }
                    : null}
                  onmousemove={hasHoverPreview()
                    ? (e) => {
                        if (previewSrc) positionPreview(e, previewEl);
                      }
                    : null}
                  onmouseleave={hasHoverPreview() ? () => (previewSrc = null) : null}
                  onclick={(e) => {
                    if (hasHoverPreview()) return;
                    e.preventDefault();
                    e.stopPropagation();
                    mobilePreviewSrc = mobilePreviewSrc === thumbSrc ? null : thumbSrc;
                  }}
                />
                <span class="recording-name">{recording.name}</span>
              </div>
              <div class="recording-footer">
                <span class="recording-size">{recording.size}</span>
                <button
                  type="button"
                  class="recording-share-button"
                  aria-label="Copy download link for {recording.name}"
                  onclick={async (e) => {
                    e.preventDefault();
                    e.stopPropagation();
                    await handleCopyLink(recording);
                  }}
                >
                  {recording._copyStatus ?? "Copy link"}
                </button>
                <button
                  type="button"
                  class="recording-download-button"
                  aria-label="Download {recording.name}"
                  onclick={(e) => {
                    e.preventDefault();
                    e.stopPropagation();
                    downloadFile(recording.name);
                  }}
                >
                  Download
                </button>
                <button
                  type="button"
                  class="recording-delete-button"
                  aria-label="Delete {recording.name}"
                  onclick={async (e) => {
                    e.preventDefault();
                    e.stopPropagation();
                    await handleDelete(recording.name);
                  }}
                >
                  Delete
                </button>
              </div>
            </div>
          {/each}
        </div>
      {/if}
    </div>
  </div>
</div>

<!-- Desktop thumbnail preview -->
{#if previewSrc}
  <div
    bind:this={previewEl}
    class="thumbnail-preview"
    style="display:block;left:{previewLeft}px;top:{previewTop}px"
  >
    <img src={previewSrc} alt="" />
  </div>
{/if}

<!-- Mobile full-screen preview -->
{#if mobilePreviewSrc}
  <!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
  <div class="mobile-preview" aria-hidden="false">
    <!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
    <div class="mobile-preview-backdrop" onclick={() => (mobilePreviewSrc = null)}>
      <img class="mobile-preview-image" src={mobilePreviewSrc} alt="" />
    </div>
  </div>
{/if}

<!-- Confirm dialog -->
<dialog id="confirm" class="backdrop:bg-black/60 rounded-xl p-0">
  <form method="dialog" class="bg-zinc-900 text-zinc-100">
    <div class="p-2">
      <p class="text-zinc-300">{confirmMessage}</p>
    </div>
    <div
      class="bg-zinc-800/60 px-4 py-3 sm:px-5 flex items-center justify-end gap-2"
    >
      <button
        type="button"
        class="px-3 py-1.5 rounded-md border border-zinc-700 text-red-400 hover:bg-zinc-800 cursor-pointer"
        onclick={handleConfirmOk}
      >
        Delete
      </button>
      <button
        type="button"
        class="px-3 py-1.5 rounded-md border border-zinc-700 text-zinc-300 hover:bg-zinc-800 cursor-pointer"
        onclick={handleConfirmCancel}
      >
        Cancel
      </button>
    </div>
  </form>
</dialog>
