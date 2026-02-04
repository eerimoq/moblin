import { addOnChange, addOnClick, addOnBlur, websocketUrl } from "./utils.mjs";

let ws = null;
let state = null;
let activeInputId = null;
let currentsportId = null;
let rangeCache = { min: 0, max: 30 };
let requestId = 0;
let confirmComplete = null;
let confirmResult = false;

const CONTROL_ORDER = [
  "primaryScore",
  "secondaryScore",
  "currentSetScore",
  "stat1",
  "stat2",
  "stat3",
  "stat4",
  "possession",
];

function updateStatus(text, colorClass) {
  const el = document.getElementById("stat");
  el.innerText = text;
  el.className = `status-text ${colorClass}`;
}

function getRequestId() {
  requestId += 1;
  return requestId;
}

function send(message) {
  if (ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify(message));
  }
}

function sendRequest(data) {
  send({
    request: {
      id: getRequestId(),
      data: data,
    },
  });
}

function sendGetStatusRequest() {
  sendRequest({
    getStatus: {},
  });
}

setInterval(() => {
  sendGetStatusRequest();
}, 2000);

function connect() {
  ws = new WebSocket(websocketUrl());
  ws.onopen = () => {
    sendRequest({
      getScoreboardSports: {},
    });
    sendGetStatusRequest();
  };
  ws.onclose = () => {
    document.getElementById("ctrl").classList.add("opacity-30", "pointer-events-none");
    updateStatus("Disconnected", "text-red-500");
    setTimeout(() => {
      updateStatus("Reconnecting", "text-red-500");
      connect();
    }, 3000);
  };
  ws.onmessage = (e) => {
    const message = JSON.parse(e.data);
    if (message.event !== undefined) {
      handleEvent(message.event.data);
    } else if (message.response !== undefined) {
      handleResponse(message.response);
    }
  };
}

function handleEvent(event) {
  // console.log("Got event", event);
  if (event.scoreboard !== undefined) {
    handleEventScoreboard(event.scoreboard);
  }
}

function handleEventScoreboard(scoreboard) {
  state = scoreboard.config;
  window.state = state;
  document.getElementById("ctrl").classList.remove("opacity-30", "pointer-events-none");
  updateStatus("Connected", "text-green-500");
  document.getElementById("si").innerText = "SYNCED";
  document.getElementById("si").className = "text-green-500";
  syncUI();
}

function handleResponse(response) {
  // console.log("Got response", response);
  if (response.data === undefined) {
    return;
  }
  if (response.data.getScoreboardSports !== undefined) {
    handleResponseGetScoreboardSports(response.data.getScoreboardSports);
  } else if (response.data.getStatus !== undefined) {
    handleResponseGetStatus(response.data.getStatus);
  }
}

function handleResponseGetScoreboardSports(getScoreboardSports) {
  const sel = document.getElementById("sport-selector");
  const currentVal = sel.value;
  sel.innerHTML =
    '<option value="">CHANGE SPORT...</option>' +
    getScoreboardSports.names
      .map((s) => `<option value="${s}">${s.toUpperCase()}</option>`)
      .join("");
  if (state && state.sportId) {
    sel.value = state.sportId;
  } else if (currentVal && getScoreboardSports.names.includes(currentVal)) {
    sel.value = currentVal;
  }
}

function handleResponseGetStatus(getStatus) {
  if (getStatus.general !== undefined) {
    document.getElementById("sp").innerText = `${getStatus.general.batteryLevel}%`;
  }
  if (getStatus.topRight.bitrate !== undefined) {
    document.getElementById("sb").innerText = getStatus.topRight.bitrate.message;
  }
}

function safeUpdate(id, value) {
  if (activeInputId !== id) {
    const el = document.getElementById(id);
    if (el && el.value !== value) {
      el.value = value;
    }
  }
}

function render() {
  if (!state || !state.controls) {
    return;
  }
  if (currentsportId !== state.sportId) {
    currentsportId = state.sportId;
    rangeCache.min = state.global.minSetScore || 0;
    rangeCache.max = state.global.maxSetScore || 30;
    buildHistoricScores();
    buildDom();
  } else {
    updateDomValues();
  }
}

function buildHistoricScores() {
  let histHtml = "";
  for (let i = 1; i <= 5; i++) {
    histHtml += `<div class="flex flex-col gap-1">
            <div id="h-lbl-${i}" onclick="window.setPeriod(${i})" class="text-center text-[9px] text-zinc-500 border border-transparent rounded cursor-pointer hover:border-zinc-600">SET ${i}</div>
            <div class="h-8 rounded bg-zinc-800 border border-zinc-700"><select id="h-t1-${i}" onchange="window.setHistoricScore(1,${i},this.value)">${historicScoreOptions()}</select></div>
            <div class="h-8 rounded bg-zinc-800 border border-zinc-700"><select id="h-t2-${i}" onchange="window.setHistoricScore(2,${i},this.value)">${historicScoreOptions()}</select></div>
        </div>`;
  }
  document.getElementById("history-grid").innerHTML = histHtml;
}

function historicScoreOptions() {
  let options = '<option value="">-</option>';
  for (let i = 0; i <= rangeCache.max; i++) {
    options += `<option value="${i}">${i}</option>`;
  }
  return options;
}

function setHistoricScore(team, idx, score) {
  state["team" + team]["secondaryScore" + idx] = score;
  if (score !== "") {
    const opp = team === 1 ? 2 : 1;
    const oppKey = "secondaryScore" + idx;
    if (!state["team" + opp][oppKey] || state["team" + opp][oppKey] === "") {
      state["team" + opp][oppKey] = "0";
    }
  }
  update();
}

function setPeriod(period) {
  state.global.period = period.toString();
  document.getElementById("period").value = period.toString();
  render();
  update();
}

function setDuration(event) {
  sendRequest({
    setScoreboardDuration: {
      minutes: parseInt(event.target.value),
    },
  });
}

function setClockDirection(event) {
  state.global.timerDirection = event.target.value;
  update();
}

function buildDom() {
  ["team1", "team2"].forEach((t, i) => {
    const n = i + 1;
    const team = state[t];
    let controlsHtml = "";

    for (let k = 0; k < CONTROL_ORDER.length; k++) {
      const key = CONTROL_ORDER[k];
      const c = state.controls[key];
      if (!c) {
        continue;
      }
      if (key === "primaryScore") {
        continue;
      }

      if (c.type === "counter") {
        controlsHtml += `<div class="grid grid-cols-2 gap-1 mb-1"><button onclick="window.adj(${n},'${key}',1)" class="btn btn-ctrl">+${c.label}</button><button onclick="window.adj(${n},'${key}',-1)" class="btn btn-ctrl">-${c.label}</button></div>`;
      } else {
        let nextKey = null;
        for (let j = k + 1; j < CONTROL_ORDER.length; j++) {
          if (state.controls[CONTROL_ORDER[j]] && CONTROL_ORDER[j] !== "primaryScore") {
            nextKey = CONTROL_ORDER[j];
            break;
          }
        }
        const nextC = nextKey ? state.controls[nextKey] : null;
        const canPack =
          nextC &&
          (nextC.type === "select" || nextC.type === "toggleTeam" || nextC.type === "cycle");

        let currentHtml = renderPacked(t, n, key, c, team);
        if (canPack) {
          let nextHtml = renderPacked(t, n, nextKey, nextC, team);
          controlsHtml += `<div class="grid grid-cols-2 gap-1 mb-1">${currentHtml}${nextHtml}</div>`;
          k = CONTROL_ORDER.indexOf(nextKey);
        } else {
          controlsHtml += `<div class="mb-1">${currentHtml}</div>`;
        }
      }
    }

    document.getElementById(`t${n}a`).innerHTML = `
            <div id="h-t${n}" class="rounded-t p-1" style="background:${team.bgColor}"><input type="text" id="in-n-${n}" onblur="window.state.${t}.name=this.value;update()" class=""></div>
            <div class="card rounded-t-none">
                <div class="grid grid-cols-4 gap-1 h-10 mb-2">
                    <div id="p-t${n}" class="disp-box" style="background:${team.bgColor};color:${team.textColor}">0</div>
                    <div id="s-t${n}" class="disp-box m-shadow" style="background:${team.bgColor};color:white">0</div>
                    <div class="rounded border border-zinc-700 bg-zinc-800"><input type="color" id="col-bg-${n}" oninput="window.liveColor(${n},'bgColor',this.value)"></div>
                    <div class="rounded border border-zinc-700 bg-zinc-800"><input type="color" id="col-txt-${n}" oninput="window.liveColor(${n},'textColor',this.value)"></div>
                </div>
                <div class="grid grid-cols-3 gap-1 mb-2">
                    <button onclick="window.adj(${n},'primaryScore',1)" class="col-span-2 btn btn-score">+Pt</button>
                    <button onclick="window.adj(${n},'primaryScore',-1)" class="col-span-1 btn btn-score">-Pt</button>
                </div>
                ${controlsHtml}
            </div>`;
  });
  updateDomValues();
}

function renderPacked(t, n, key, c, team) {
  if (c.type === "select") {
    return `<div class="disp-sm bg-zinc-800"><select id="sel-${t}-${key}" onchange="window.state.${t}.${key}=this.value;update()">${c.options.map((v) => `<option value="${v}">${c.label}: ${v}</option>`).join("")}</select></div>`;
  } else if (c.type === "toggleTeam") {
    return `<button id="btn-tog-${n}-${key}" onclick="window.toggleTeam(${n})" class="btn btn-ctrl">${c.label}</button>`;
  } else if (c.type === "cycle") {
    const txt = c.label ? `${c.label}: ${team[key] || "NONE"}` : `${team[key] || "NONE"}`;
    return `<button id="btn-${t}-${key}" onclick="window.cycle(${n},'${key}')" class="btn btn-ctrl">${txt}</button>`;
  }
  return "";
}

function updateDomValues() {
  ["team1", "team2"].forEach((t, i) => {
    const n = i + 1;
    const team = state[t];

    const h = document.getElementById(`h-t${n}`);
    const p = document.getElementById(`p-t${n}`);
    const s = document.getElementById(`s-t${n}`);
    h.style.background = team.bgColor;
    p.style.background = team.bgColor;
    s.style.background = team.bgColor;
    p.style.color = team.textColor;
    s.style.color = "white";

    if (activeInputId !== `col-bg-${n}`) {
      document.getElementById(`col-bg-${n}`).value = team.bgColor;
    }
    if (activeInputId !== `col-txt-${n}`) {
      document.getElementById(`col-txt-${n}`).value = team.textColor;
    }

    safeUpdate(`in-n-${n}`, team.name);
    document.getElementById(`p-t${n}`).innerText = team.primaryScore;

    let secScore = team.secondaryScore || "-";
    if (state.global.scoringMode === "tennis") {
      const p = state.global.period;
      secScore = team["secondaryScore" + p] || "0";
    }
    document.getElementById(`s-t${n}`).innerText = secScore;

    for (let j = 1; j <= 5; j++) {
      const hSel = document.getElementById(`h-t${n}-${j}`);
      if (hSel && activeInputId !== `h-t${n}-${j}`) hSel.value = team["secondaryScore" + j] || "";
      const lbl = document.getElementById(`h-lbl-${j}`);
      if (lbl) {
        if (state.global.period == j.toString()) {
          lbl.classList.add("active-set", "border-yellow-600");
        } else {
          lbl.classList.remove("active-set", "border-yellow-600");
        }
      }
    }

    Object.keys(state.controls).forEach((key) => {
      if (key === "primaryScore") {
        return;
      }
      const c = state.controls[key];
      const val = team[key] || "";

      if (c.type === "cycle") {
        const btn = document.getElementById(`btn-${t}-${key}`);
        if (btn) {
          btn.innerText = c.label ? `${c.label}: ${val}` : val;
          const isActive = val && val !== "NONE" && !val.startsWith("NO ");
          if (isActive) {
            btn.classList.add("btn-accent");
          } else {
            btn.classList.remove("btn-accent");
          }
        }
      } else if (c.type === "select") {
        const sel = document.getElementById(`sel-${t}-${key}`);
        if (sel && activeInputId !== `sel-${t}-${key}`) {
          sel.value = val;
        }
      } else if (c.type === "toggleTeam") {
        const btn = document.getElementById(`btn-tog-${n}-${key}`);
        if (btn) {
          const isActive = team.possession === true;
          if (isActive) {
            btn.classList.add("btn-accent");
            btn.classList.remove("text-zinc-500");
          } else {
            btn.classList.remove("btn-accent");
            btn.classList.add("text-zinc-500");
          }
        }
      }
    });
  });
}

function switchSport(event) {
  if (!event.target.value) {
    return;
  }
  sendRequest({
    setScoreboardSport: {
      sportId: event.target.value,
    },
  });
}

function switchLayout(event) {
  if (!event.target.value) {
    return;
  }
  state.layout = event.target.value;
  update();
}

function toggleButtonState(key) {
  state.global[key] = !state.global[key];
  updateGlobalToggles();
  update();
}

function toggleButtonStyle(elementId, enabled) {
  const element = document.getElementById(elementId);
  if (enabled) {
    element.classList.add("btn-active");
  } else {
    element.classList.remove("btn-active");
  }
}

function updateGlobalToggles() {
  toggleButtonStyle("btn-show-title", state.global.showTitle);
  toggleButtonStyle("btn-info-box", state.global.showStats);
  toggleButtonStyle("btn-more-stats", state.global.showMoreStats);
}

function liveColor(n, k, v) {
  state["team" + n][k] = v;
  const h = document.getElementById(`h-t${n}`),
    p = document.getElementById(`p-t${n}`),
    s = document.getElementById(`s-t${n}`);
  if (k === "bgColor") {
    if (h) {
      h.style.background = v;
    }
    if (p) {
      p.style.background = v;
    }
    if (s) {
      s.style.background = v;
    }
  } else {
    if (p) {
      p.style.color = v;
    }
    if (s) {
      s.style.color = "white";
    }
  }
  update();
}

function syncUI() {
  render();
  safeUpdate("title", state.global.title);
  safeUpdate("clock", state.global.timer);
  safeUpdate("period", state.global.period);
  safeUpdate("info-box", state.global.infoBoxText);
  document.getElementById("lbl-period").innerText = state.global.periodLabel || "PER";

  if (activeInputId !== "clock-direction") {
    document.getElementById("clock-direction").value = state.global.timerDirection;
  }

  const sel = document.getElementById("sport-selector");
  if (
    activeInputId !== "sport-selector" &&
    state.sportId &&
    sel.querySelector(`option[value="${state.sportId}"]`)
  ) {
    sel.value = state.sportId;
  }

  if (activeInputId !== "layout-selector" && state.layout) {
    document.getElementById("layout-selector").value = state.layout;
  }

  document.getElementById("next-set").innerText =
    state.global.scoringMode === "tennis" ? "Start next set" : "Next set/period";

  if (state.global.duration && activeInputId !== "clock-maximum") {
    document.getElementById("clock-maximum").value = state.global.duration;
  }

  updateGlobalToggles();
}

function sendToggleClock() {
  sendRequest({ toggleScoreboardClock: {} });
}

function adj(t, k, v) {
  if (state.global.scoringMode === "tennis" && k === "primaryScore") {
    adjTennis(t, v);
    return;
  }
  if (k === "currentSetScore") {
    const setNum = parseInt(state.global.period) || 1;
    if (setNum >= 1 && setNum <= 5) {
      const actualKey = "secondaryScore" + setNum;
      const currentVal = parseInt(state["team" + t][actualKey]) || 0;
      state["team" + t][actualKey] = Math.max(0, currentVal + v).toString();
      const opp = t === 1 ? 2 : 1;
      const oppKey = "secondaryScore" + setNum;
      if (!state["team" + opp][oppKey] || state["team" + opp][oppKey] === "") {
        state["team" + opp][oppKey] = "0";
      }
      update();
    }
    return;
  }
  state["team" + t][k] = Math.max(0, parseInt(state["team" + t][k] || 0) + v).toString();
  if (k === "primaryScore" && v > 0 && state.global.changePossessionOnScore) {
    toggleTeam(t);
  }
  render();
  update();
}

function adjTennis(t, v) {
  const tKey = "team" + t;
  const oKey = "team" + (t === 1 ? 2 : 1);
  let val = state[tKey].primaryScore;
  let oppVal = state[oKey].primaryScore;

  if (v > 0) {
    if (val === "0") {
      val = "15";
    } else if (val === "15") {
      val = "30";
    } else if (val === "30") {
      if (oppVal === "40") {
        val = "D";
        state[oKey].primaryScore = "D";
      } else {
        val = "40";
      }
    } else if (val === "40") {
      if (oppVal === "Ad") {
        val = "D";
        state[oKey].primaryScore = "D";
      } else if (oppVal === "40" || oppVal === "D") {
        val = "Ad";
      } else {
        winGame(t);
        return;
      }
    } else if (val === "D") {
      if (oppVal === "Ad") {
        state[oKey].primaryScore = "D";
      } else {
        val = "Ad";
      }
    } else if (val === "Ad") {
      winGame(t);
      return;
    }
  } else {
    if (val === "Ad") {
      val = "D";
    } else if (val === "D") {
      val = "40";
    } else if (val === "40") {
      val = "30";
    } else if (val === "30") {
      val = "15";
    } else if (val === "15") {
      val = "0";
    }
  }

  state[tKey].primaryScore = val;
  render();
  update();
}

async function confirm(message) {
  document.getElementById("confirm-message").innerHTML = message;
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

function winGame(t) {
  state.team1.primaryScore = "0";
  state.team2.primaryScore = "0";
  adj(t, "currentSetScore", 1);
  const nextServer = state.team1.possession ? 2 : 1;
  toggleTeam(nextServer);
  render();
  update();
}

function cycle(t, k) {
  const opts = state.controls[k].options;
  const curr = state["team" + t][k] || "";
  let idx = opts.indexOf(curr);
  state["team" + t][k] = opts[(idx + 1) % opts.length];
  update();
}

function toggleTeam(tIndex) {
  state.team1.possession = tIndex === 1;
  state.team2.possession = tIndex === 2;
  render();
  update();
}

async function resetSet() {
  if (state.global.scoringMode === "tennis") {
    if (!(await confirm("Start next set?"))) {
      return;
    }
    let p = parseInt(state.global.period) || 0;
    state.global.period = (p + 1).toString();

    const el = document.getElementById("period");
    if (el) {
      el.value = state.global.period;
    }

    state.team1.primaryScore = "0";
    state.team2.primaryScore = "0";
    // Tennis doesn't reset possession usually, logic preserved

    update();
    return;
  }

  if (!(await confirm("Start next set/period?"))) {
    return;
  }

  let slot = -1;
  for (let i = 1; i <= 5; i++) {
    if (!state.team1["secondaryScore" + i] && !state.team2["secondaryScore" + i]) {
      slot = i;
      break;
    }
  }
  if (slot !== -1) {
    state.team1["secondaryScore" + slot] = state.team1.primaryScore;
    state.team2["secondaryScore" + slot] = state.team2.primaryScore;

    if (state.team1["secondaryScore" + slot] && !state.team2["secondaryScore" + slot]) {
      state.team2["secondaryScore" + slot] = "0";
    }
    if (state.team2["secondaryScore" + slot] && !state.team1["secondaryScore" + slot]) {
      state.team1["secondaryScore" + slot] = "0";
    }
  }

  let p = parseInt(state.global.period) || 0;
  state.global.period = (p + 1).toString();

  const el = document.getElementById("period");
  if (el) el.value = state.global.period;

  Object.keys(state.controls).forEach((k) => {
    if (state.controls[k].periodReset) {
      let def = "0";
      if (state.controls[k].options && state.controls[k].options.length > 0) {
        def = state.controls[k].options[0];
      } else if (state.controls[k].type === "toggleTeam") {
        def = false;
        return;
      }
      state.team1[k] = def;
      state.team2[k] = def;
    }
  });

  if (state.global.primaryScoreResetOnPeriod) {
    state.team1.primaryScore = "0";
    state.team2.primaryScore = "0";
  }
  if (state.global.secondaryScoreResetOnPeriod) {
    state.team1.secondaryScore = "0";
    state.team2.secondaryScore = "0";
  }
  update();
}

async function newMatch() {
  if (!(await confirm("Start new match? This clears scores and stats."))) {
    return;
  }
  if (state.global.timerDirection == "up") {
    state.global.timer = "00:00";
  } else {
    state.global.timer = `${parseInt(state.global.duration)}:00`;
  }
  document.getElementById("period").value = "1";
  Object.keys(state.controls).forEach((k) => {
    let def = "0";
    if (state.controls[k].options && state.controls[k].options.length > 0) {
      def = state.controls[k].options[0];
    } else if (state.controls[k].type === "toggleTeam") {
      state.team1.possession = true;
      state.team2.possession = false;
      return;
    }
    state.team1[k] = def;
    state.team2[k] = def;
  });
  state.team1.primaryScore = "0";
  state.team2.primaryScore = "0";
  if (state.team1.secondaryScore === "") {
    state.team1.secondaryScore = "";
    state.team2.secondaryScore = "";
  } else {
    state.team1.secondaryScore = "0";
    state.team2.secondaryScore = "0";
  }
  for (let i = 1; i <= 5; i++) {
    state.team1["secondaryScore" + i] = null;
    state.team2["secondaryScore" + i] = null;
  }
  update();
}

function update() {
  state.global.title = document.getElementById("title").value;

  // Fix: Capture clock value to prevent revert, and send manual update if focused
  if (activeInputId === "clock") {
    state.global.timer = document.getElementById("clock").value; // Update local state so it doesn't revert on echo
    sendRequest({ setScoreboardClock: { time: state.global.timer } });
  } else {
    // If not focused, we don't send clock back, we let server drive it
    // But we need to ensure we don't send "00:00" if we haven't rendered yet
    // state.global.timer is authoritative from server usually
  }

  state.global.period = document.getElementById("period").value;
  state.global.infoBoxText = document.getElementById("info-box").value;
  sendRequest({
    updateScoreboard: {
      config: state,
    },
  });
}

window.setPeriod = setPeriod;
window.adj = adj;
window.toggleTeam = toggleTeam;
window.cycle = cycle;
window.state = state;
window.setHistoricScore = setHistoricScore;
window.liveColor = liveColor;

window.addEventListener("DOMContentLoaded", async () => {
  let clockMaximumOptions = "";
  for (let i = 1; i <= 120; i++) {
    clockMaximumOptions += `<option value=${i}>${i} min</option>`;
  }
  document.getElementById("clock-maximum").innerHTML = clockMaximumOptions;
  addOnChange("clock-maximum", setDuration);
  addOnChange("clock-direction", setClockDirection);
  addOnChange("layout-selector", switchLayout);
  addOnChange("sport-selector", switchSport);
  addOnClick("toggle-clock", sendToggleClock);
  addOnClick("next-set", resetSet);
  addOnClick("new-match", newMatch);
  addOnClick("btn-show-title", () => {
    toggleButtonState("showTitle");
  });
  addOnClick("btn-more-stats", () => {
    toggleButtonState("showMoreStats");
  });
  addOnClick("btn-info-box", () => {
    toggleButtonState("showStats");
  });
  addOnClick("confirm-ok", confirmOk);
  addOnClick("confirm-cancel", confirmCancel);
  addOnBlur("info-box", update);
  addOnBlur("title", update);
  addOnBlur("clock", update);
  addOnBlur("period", update);
  connect();
});

document.addEventListener("focusin", function (e) {
  activeInputId = e.target.id;
});

document.addEventListener("focusout", function () {
  activeInputId = null;
});
