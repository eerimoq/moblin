import { websocketUrl, confirm, confirmOk, confirmCancel } from "./utils.mjs";

const DEFAULT_PARS_18 = [4, 4, 3, 4, 5, 4, 3, 4, 4, 4, 4, 3, 5, 4, 4, 3, 4, 5];
const DEFAULT_PARS_9 = [4, 4, 3, 4, 5, 4, 3, 4, 4];
const MAX_HOLES = DEFAULT_PARS_18.length;
const MAX_SCORE = 9;

const local = {
  title: "",
  number: 18,
  pars: [...DEFAULT_PARS_18],
  currentHole: 0,
  players: [
    { name: "Player 1", scores: Array(MAX_HOLES).fill(-1) },
    { name: "Player 2", scores: Array(MAX_HOLES).fill(-1) },
  ],
};

let ws = null;
let requestId = 0;

function getRequestId() {
  return ++requestId;
}

function send(msg) {
  if (ws && ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify(msg));
  }
}

function sendRequest(data) {
  send({ request: { id: getRequestId(), data } });
}

function sendGetGolfScoreboard() {
  sendRequest({ getGolfScoreboard: {} });
}

function sendUpdateGolfScoreboard() {
  sendRequest({
    updateGolfScoreboard: {
      data: {
        title: local.title,
        numberOfHoles: local.numberOfHoles,
        pars: local.pars,
        currentHole: local.currentHole,
        players: local.players.map((p) => ({ name: p.name, scores: p.scores })),
      },
    },
  });
}

function connect() {
  ws = new WebSocket(websocketUrl());
  ws.onopen = () => {
    setStatus("Connected", "text-green-500");
    sendGetGolfScoreboard();
  };
  ws.onclose = () => {
    setStatus("Disconnected – reconnecting…", "text-red-500");
    setTimeout(connect, 3000);
  };
  ws.onerror = () => {
    setStatus("Connection error", "text-yellow-500");
  };
  ws.onmessage = (e) => {
    handleMessage(JSON.parse(e.data));
  };
}

function handleMessage(msg) {
  if (msg.response?.data?.getGolfScoreboard) {
    applyRemoteState(msg.response.data.getGolfScoreboard.data);
    return;
  }
  if (msg.event?.data?.golfScoreboard) {
    applyRemoteState(msg.event.data.golfScoreboard.data);
  }
}

function applyRemoteState(data) {
  if (!data) return;
  local.title = data.title ?? local.title;
  local.numberOfHoles = data.numberOfHoles ?? local.numberOfHoles;
  if (Array.isArray(data.pars) && data.pars.length >= 18) {
    local.pars = data.pars;
  }
  local.currentHole = data.currentHole ?? local.currentHole;
  if (Array.isArray(data.players) && data.players.length > 0) {
    local.players = data.players.map((p) => ({
      name: p.name,
      scores: ensureLength(p.scores ?? [], MAX_HOLES, -1),
    }));
  }
  renderAll();
}

function ensureLength(arr, len, fill) {
  const out = [...arr];
  while (out.length < len) out.push(fill);
  return out;
}

function totalRelativeToPar(playerIndex) {
  let total = 0;
  for (let h = 0; h < local.numberOfHoles; h++) {
    const s = local.players[playerIndex].scores[h];
    if (s >= 0) total += s - local.pars[h];
  }
  return total;
}

function holesPlayed(playerIndex) {
  return local.players[playerIndex].scores.slice(0, local.numberOfHoles).filter((s) => s >= 0)
    .length;
}

function fmtRelPar(val) {
  if (val === 0) return "E";
  return val > 0 ? `+${val}` : `${val}`;
}

function scoreClass(strokes, par) {
  if (strokes < 0) return "empty-cell";
  const d = strokes - par;
  if (d <= -2) return "eagle";
  if (d === -1) return "birdie";
  if (d === 0) return "par-cell";
  if (d === 1) return "bogey";
  if (d === 2) return "double-bogey";
  return "triple-bogey";
}

function totalClass(val) {
  if (val < 0) return "score-under";
  if (val > 0) return "score-over";
  return "score-even";
}

function esc(s) {
  return String(s)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function setStatus(text, cls) {
  const el = document.getElementById("status");
  el.textContent = text;
  el.className = `text-sm ${cls}`;
}

function renderAll() {
  syncEventInputs();
  renderPlayerList();
  renderHoleButtons();
  renderScoreInputs();
  renderLeaderboard();
  renderScorecard();
}

function syncEventInputs() {
  const nameEl = document.getElementById("title");
  const holesEl = document.getElementById("number-of-holes");
  if (nameEl && document.activeElement !== nameEl) nameEl.value = local.title;
  if (holesEl) holesEl.value = String(local.numberOfHoles);
}

function renderPlayerList() {
  const container = document.getElementById("player-list");
  if (!container) return;
  const focusedId = document.activeElement?.id ?? null;
  container.innerHTML = "";
  local.players.forEach((p, i) => {
    const row = document.createElement("div");
    row.className = "flex items-center gap-2";
    row.innerHTML = `
      <span class="text-xs text-zinc-500 w-16 shrink-0">Player ${i + 1}</span>
      <input
        type="text"
        id="player-name-${i}"
        class="flex-1 bg-zinc-800 border border-zinc-700 rounded px-2 py-1 text-sm"
        placeholder="Name"
        value="${esc(p.name)}"
      />`;
    container.appendChild(row);
    const input = row.querySelector("input");
    input.addEventListener("blur", () => {
      local.players[i].name = input.value || `Player ${i + 1}`;
      renderLeaderboard();
      renderScorecard();
      sendUpdateGolfScoreboard();
    });
    if (focusedId === `player-name-${i}`) {
      requestAnimationFrame(() => {
        input.focus();
      });
    }
  });
  const removeBtn = document.getElementById("btn-remove-player");
  const addBtn = document.getElementById("btn-add-player");
  if (removeBtn) removeBtn.disabled = local.players.length <= 1;
  if (addBtn) addBtn.disabled = local.players.length >= 4;
}

function renderHoleButtons() {
  const container = document.getElementById("hole-buttons");
  if (!container) return;
  container.innerHTML = "";
  for (let h = 0; h < local.numberOfHoles; h++) {
    const btn = document.createElement("button");
    const allScored = local.players.every((p) => p.scores[h] >= 0);
    const anyScored = local.players.some((p) => p.scores[h] >= 0);
    const isActive = h === local.currentHole;
    let extraClass = "";
    if (!isActive) {
      if (allScored) {
        extraClass = " complete";
      } else if (anyScored) {
        extraClass = " played";
      }
    }
    btn.className = "hole-btn" + (isActive ? " active" : "") + extraClass;
    btn.textContent = String(h + 1);
    btn.addEventListener("click", () => selectHole(h));
    container.appendChild(btn);
  }
  const parInput = document.getElementById("current-par");
  if (parInput) parInput.value = String(local.pars[local.currentHole] ?? 4);
  const holeNum = document.getElementById("entry-hole-num");
  if (holeNum) holeNum.textContent = String(local.currentHole + 1);
}

function selectHole(h) {
  local.currentHole = h;
  renderHoleButtons();
  renderScoreInputs();
  sendUpdateGolfScoreboard();
}

function scoreOptionColor(score, par) {
  if (score < 0) return "";
  const d = score - par;
  if (d <= -2) return "#60a5fa";
  if (d === -1) return "#4ade80";
  if (d === 0) return "";
  if (d === 1) return "#f74e4e";
  if (d === 2) return "#c084fc";
  return "#8a5a2b";
}

function renderScoreInputs() {
  const container = document.getElementById("player-score-inputs");
  if (!container) return;
  const holeNum = document.getElementById("entry-hole-num");
  if (holeNum) holeNum.textContent = String(local.currentHole + 1);
  container.innerHTML = "";
  const par = local.pars[local.currentHole] ?? 4;
  local.players.forEach((p, i) => {
    const val = p.scores[local.currentHole];
    const hasScore = val >= 0;
    const row = document.createElement("div");
    row.className = "flex items-center gap-2";
    const options =
      Array.from({ length: MAX_SCORE }, (_, k) => {
        const score = MAX_SCORE - k;
        const color = scoreOptionColor(score, par);
        const rel = fmtRelPar(score - par);
        return `<option value="${score}"${val === score ? " selected" : ""} style="color:${color}">${score} (${rel})</option>`;
      }).join("") + `<option value="-1"${!hasScore ? " selected" : ""}>-</option>`;
    const selColor = hasScore ? scoreOptionColor(val, par) : "";
    const selStyle = selColor ? `style="color:${selColor}"` : "";
    row.innerHTML = `
      <span class="text-sm flex-1 truncate">${esc(p.name)}</span>
      <select id="sv-${i}" class="score-select" data-p="${i}" ${selStyle}>${options}</select>`;
    container.appendChild(row);
  });

  container.querySelectorAll(".score-select").forEach((sel) => {
    sel.addEventListener("change", () => {
      const pi = parseInt(sel.dataset.p);
      const score = parseInt(sel.value);
      local.players[pi].scores[local.currentHole] = score;
      sel.style.color = scoreOptionColor(score, par);
      renderHoleButtons();
      renderLeaderboard();
      renderScorecard();
      sendUpdateGolfScoreboard();
    });
  });
}

function renderLeaderboard() {
  const tbody = document.getElementById("leaderboard-body");
  if (!tbody) return;
  tbody.innerHTML = "";
  const rows = local.players
    .map((p, i) => ({ name: p.name, total: totalRelativeToPar(i), thru: holesPlayed(i) }))
    .sort((a, b) => a.total - b.total);
  rows.forEach(({ name, total, thru }) => {
    const cls = totalClass(total);
    const thruText = thru === 0 ? "–" : thru < local.numberOfHoles ? String(thru) : "F";
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td class="py-1 truncate max-w-xs">${esc(name)}</td>
      <td class="text-right font-bold text-base ${cls}">${fmtRelPar(total)}</td>
      <td class="text-right text-zinc-500 text-xs">${thruText}</td>`;
    tbody.appendChild(tr);
  });
}

function renderScorecard() {
  const table = document.getElementById("scorecard");
  if (!table) return;
  table.innerHTML = "";

  const thead = document.createElement("thead");
  const hr = document.createElement("tr");
  hr.innerHTML =
    `<th class="player-name-cell">Player</th>` +
    Array.from({ length: local.numberOfHoles }, (_, h) => `<th>${h + 1}</th>`).join("") +
    `<th class="total-cell">Total</th>`;
  thead.appendChild(hr);
  table.appendChild(thead);

  const tbody = document.createElement("tbody");

  const parRow = document.createElement("tr");
  const coursePar = local.pars.slice(0, local.numberOfHoles).reduce((a, b) => a + b, 0);
  parRow.innerHTML =
    `<td class="player-name-cell text-zinc-500">Par</td>` +
    local.pars
      .slice(0, local.numberOfHoles)
      .map((p) => `<td class="text-zinc-500">${p}</td>`)
      .join("") +
    `<td class="total-cell text-zinc-500">${coursePar}</td>`;
  tbody.appendChild(parRow);

  local.players.forEach((p, i) => {
    const total = totalRelativeToPar(i);
    const tr = document.createElement("tr");
    let cells = `<td class="player-name-cell">${esc(p.name)}</td>`;
    for (let h = 0; h < local.numberOfHoles; h++) {
      const s = p.scores[h];
      const cls = scoreClass(s, local.pars[h]);
      cells += `<td class="${cls}">${s >= 0 ? s : ""}</td>`;
    }
    cells += `<td class="total-cell ${totalClass(total)}">${fmtRelPar(total)}</td>`;
    tr.innerHTML = cells;
    tbody.appendChild(tr);
  });

  table.appendChild(tbody);
}

function bindEvents() {
  document.getElementById("title")?.addEventListener("blur", (e) => {
    local.title = e.target.value || "";
    sendUpdateGolfScoreboard();
  });

  document.getElementById("number-of-holes")?.addEventListener("change", (e) => {
    const n = parseInt(e.target.value);
    local.numberOfHoles = n;
    local.pars = n === 9 ? [...DEFAULT_PARS_9] : [...DEFAULT_PARS_18];
    if (local.currentHole >= n) local.currentHole = n - 1;
    renderHoleButtons();
    renderScoreInputs();
    renderLeaderboard();
    renderScorecard();
    sendUpdateGolfScoreboard();
  });

  document.getElementById("current-par")?.addEventListener("change", (e) => {
    const p = parseInt(e.target.value);
    if (isNaN(p)) return;
    local.pars[local.currentHole] = p;
    renderScoreInputs();
    renderLeaderboard();
    renderScorecard();
    sendUpdateGolfScoreboard();
  });

  document.getElementById("btn-add-player")?.addEventListener("click", async () => {
    if (local.players.length >= 4) return;
    const n = local.players.length + 1;
    local.players.push({ name: `Player ${n}`, scores: Array(MAX_HOLES).fill(-1) });
    renderAll();
    sendUpdateGolfScoreboard();
  });

  document.getElementById("btn-remove-player")?.addEventListener("click", async () => {
    if (local.players.length <= 1) return;
    if (!(await confirm("Remove the last player?"))) return;
    local.players.pop();
    renderAll();
    sendUpdateGolfScoreboard();
  });

  document.getElementById("btn-new-round")?.addEventListener("click", async () => {
    if (!(await confirm("Start a new round? All scores will be cleared."))) return;
    local.players.forEach((p) => {
      p.scores = Array(MAX_HOLES).fill(-1);
    });
    local.currentHole = 0;
    renderAll();
    sendUpdateGolfScoreboard();
  });

  document.getElementById("confirm-ok")?.addEventListener("click", confirmOk);
  document.getElementById("confirm-cancel")?.addEventListener("click", confirmCancel);
}

window.addEventListener("DOMContentLoaded", () => {
  renderAll();
  bindEvents();
  connect();
});
