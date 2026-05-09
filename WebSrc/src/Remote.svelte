<svelte:head>
  <title>Moblin Scoreboard Control</title>
  <link rel="stylesheet" href="css/app.css" />
  <link rel="stylesheet" href="css/common.css" />
  <link rel="stylesheet" href="css/remote.css" />
</svelte:head>

<script>
  import { websocketUrl } from "./lib/websocket.js";

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

  // Reactive state
  let state = $state(null);
  let statusText = $state("Disconnected");
  let statusColor = $state("text-red-500");
  let syncText = $state("");
  let syncColor = $state("");
  let battery = $state("");
  let bitrateText = $state("");
  let sportNames = $state([]);
  let activeInputId = $state(null);
  let clockDetailsHidden = $state(true);
  let rangeCache = $state({ min: 0, max: 30 });
  let requestId = 0;
  let ws = $state(null);

  // Clock maximum options
  const clockMaximumOptions = Array.from({ length: 120 }, (_, i) => i + 1);

  function getRequestId() {
    requestId += 1;
    return requestId;
  }

  function send(message) {
    if (ws && ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify(message));
    }
  }

  function sendRequest(data) {
    send({ request: { id: getRequestId(), data } });
  }

  function sendGetStatusRequest() {
    sendRequest({ getStatus: {} });
  }

  function sendUpdateScoreboard() {
    if (state) sendRequest({ updateScoreboard: { config: state } });
  }

  function sendToggleClock() {
    sendRequest({ toggleScoreboardClock: {} });
  }

  function connect() {
    ws = new WebSocket(websocketUrl());
    ws.onopen = () => {
      sendRequest({ getScoreboardSports: {} });
      sendGetStatusRequest();
    };
    ws.onclose = () => {
      if (state) {
        state = null;
      }
      statusText = "Disconnected";
      statusColor = "text-red-500";
      syncText = "";
      syncColor = "";
      setTimeout(() => {
        statusText = "Reconnecting";
        connect();
      }, 3000);
    };
    ws.onmessage = (e) => {
      const message = JSON.parse(e.data);
      if (message.event !== undefined) handleEvent(message.event.data);
      else if (message.response !== undefined) handleResponse(message.response);
    };
  }

  setInterval(sendGetStatusRequest, 2000);

  function handleEvent(event) {
    if (event.scoreboard !== undefined) handleEventScoreboard(event.scoreboard);
  }

  function handleEventScoreboard(scoreboard) {
    state = scoreboard.config;
    statusText = "Connected";
    statusColor = "text-green-500";
    syncText = "SYNCED";
    syncColor = "text-green-500";
    if (state.global) {
      rangeCache.min = state.global.minSetScore || 0;
      rangeCache.max = state.global.maxSetScore || 30;
      clockDetailsHidden = !state.global.showClock;
    }
  }

  function handleResponse(response) {
    if (response.data === undefined) return;
    if (response.data.getScoreboardSports !== undefined) {
      sportNames = response.data.getScoreboardSports.names;
    } else if (response.data.getStatus !== undefined) {
      const status = response.data.getStatus;
      if (status.general !== undefined) battery = `${status.general.batteryLevel}%`;
      if (status.topRight?.bitrate !== undefined) bitrateText = status.topRight.bitrate.message;
    }
  }

  // Team actions
  function adjust(teamNum, key, delta) {
    if (!state) return;
    const tKey = "team" + teamNum;
    if (state.global?.scoringMode === "tennis" && key === "primaryScore") {
      adjTennis(teamNum, delta);
      return;
    }
    if (key === "currentSetScore") {
      const setNum = parseInt(state.global.period) || 1;
      if (setNum >= 1 && setNum <= 5) {
        const actualKey = "secondaryScore" + setNum;
        const currentVal = parseInt(state[tKey][actualKey]) || 0;
        state[tKey][actualKey] = Math.max(0, currentVal + delta).toString();
        const opp = teamNum === 1 ? 2 : 1;
        const oppKey = "secondaryScore" + setNum;
        if (!state["team" + opp][oppKey] || state["team" + opp][oppKey] === "") {
          state["team" + opp][oppKey] = "0";
        }
        sendUpdateScoreboard();
      }
      return;
    }
    state[tKey][key] = Math.max(0, parseInt(state[tKey][key] || 0) + delta).toString();
    if (key === "primaryScore" && delta > 0 && state.global?.changePossessionOnScore) {
      toggleTeam(teamNum);
    }
    state = state;
    sendUpdateScoreboard();
  }

  function toggleTeam(tIndex) {
    if (!state) return;
    state.team1.possession = tIndex === 1;
    state.team2.possession = tIndex === 2;
    state = state;
    sendUpdateScoreboard();
  }

  function cycle(teamNum, key) {
    if (!state) return;
    const tKey = "team" + teamNum;
    const opts = state.controls[key].options;
    const curr = state[tKey][key] || "";
    let idx = opts.indexOf(curr);
    state[tKey][key] = opts[(idx + 1) % opts.length];
    state = state;
    sendUpdateScoreboard();
  }

  function setHistoricScore(team, idx, score) {
    if (!state) return;
    state["team" + team]["secondaryScore" + idx] = score;
    if (score !== "") {
      const opp = team === 1 ? 2 : 1;
      const oppKey = "secondaryScore" + idx;
      if (!state["team" + opp][oppKey] || state["team" + opp][oppKey] === "") {
        state["team" + opp][oppKey] = "0";
      }
    }
    state = state;
    sendUpdateScoreboard();
  }

  function setHistoricPeriod(period) {
    if (!state) return;
    state.global.period = period.toString();
    state = state;
    sendUpdateScoreboard();
  }

  function adjTennis(t, v) {
    if (!state) return;
    const tKey = "team" + t;
    const oKey = "team" + (t === 1 ? 2 : 1);
    let val = state[tKey].primaryScore;
    let oppVal = state[oKey].primaryScore;

    if (v > 0) {
      switch (val) {
        case "0": val = "15"; break;
        case "15": val = "30"; break;
        case "30":
          if (oppVal === "40") { val = "D"; state[oKey].primaryScore = "D"; }
          else val = "40";
          break;
        case "40":
          if (oppVal === "Ad") { val = "D"; state[oKey].primaryScore = "D"; }
          else if (oppVal === "40" || oppVal === "D") val = "Ad";
          else { winGame(t); return; }
          break;
        case "D":
          if (oppVal === "Ad") state[oKey].primaryScore = "D";
          else val = "Ad";
          break;
        case "Ad": winGame(t); return;
      }
    } else {
      switch (val) {
        case "Ad": val = "D"; break;
        case "D": val = "40"; break;
        case "40": val = "30"; break;
        case "30": val = "15"; break;
        case "15": val = "0"; break;
      }
    }
    state[tKey].primaryScore = val;
    state = state;
    sendUpdateScoreboard();
  }

  function winGame(t) {
    if (!state) return;
    state.team1.primaryScore = "0";
    state.team2.primaryScore = "0";
    const nextServer = state.team1.possession ? 2 : 1;
    toggleTeam(nextServer);
    adjust(t, "currentSetScore", 1);
  }

  async function resetSet() {
    if (!state) return;
    if (state.global.scoringMode === "tennis") {
      if (!(await confirmDialog("Start next set?"))) return;
      let p = parseInt(state.global.period) || 0;
      state.global.period = (p + 1).toString();
      state.team1.primaryScore = "0";
      state.team2.primaryScore = "0";
      state = state;
      sendUpdateScoreboard();
      return;
    }
    if (!(await confirmDialog("Start next set/period?"))) return;
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
      if (state.team1["secondaryScore" + slot] && !state.team2["secondaryScore" + slot])
        state.team2["secondaryScore" + slot] = "0";
      if (state.team2["secondaryScore" + slot] && !state.team1["secondaryScore" + slot])
        state.team1["secondaryScore" + slot] = "0";
    }
    let p = parseInt(state.global.period) || 0;
    state.global.period = (p + 1).toString();
    Object.keys(state.controls).forEach((k) => {
      if (state.controls[k].periodReset) {
        let def = "0";
        if (state.controls[k].options?.length > 0) def = state.controls[k].options[0];
        else if (state.controls[k].type === "toggleTeam") {
          state.team1[k] = false;
          state.team2[k] = false;
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
    state = state;
    sendUpdateScoreboard();
  }

  async function newMatch() {
    if (!state) return;
    if (!(await confirmDialog("Start new match? This clears scores and stats."))) return;
    if (state.global.timerDirection === "up") {
      state.global.timer = "0:00";
    } else {
      state.global.timer = `${parseInt(state.global.duration)}:00`;
    }
    state.global.period = "1";
    Object.keys(state.controls).forEach((k) => {
      if (state.controls[k].type === "toggleTeam") {
        state.team1.possession = true;
        state.team2.possession = false;
        return;
      }
      let def = "0";
      if (state.controls[k].options?.length > 0) def = state.controls[k].options[0];
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
    state = state;
    sendUpdateScoreboard();
  }

  function toggleButtonState(key) {
    if (!state) return;
    state.global[key] = !state.global[key];
    if (key === "showClock") clockDetailsHidden = !state.global.showClock;
    state = state;
    sendUpdateScoreboard();
  }

  function switchSport(sportId) {
    if (!sportId) return;
    sendRequest({ setScoreboardSport: { sportId } });
  }

  function switchLayout(layout) {
    if (!layout || !state) return;
    state.layout = layout;
    state = state;
    sendUpdateScoreboard();
  }

  function setDuration(minutes) {
    sendRequest({ setScoreboardDuration: { minutes: parseInt(minutes) } });
  }

  function setClockDirection(dir) {
    if (!state) return;
    state.global.timerDirection = dir;
    state = state;
    sendUpdateScoreboard();
  }

  function setClock(time) {
    sendRequest({ setScoreboardClock: { time } });
  }

  function setTitle(value) {
    if (!state) return;
    state.global.title = value;
    state = state;
    sendUpdateScoreboard();
  }

  function setPeriod(value) {
    if (!state) return;
    state.global.period = value;
    state = state;
    sendUpdateScoreboard();
  }

  function setInfoBoxText(value) {
    if (!state) return;
    state.global.infoBoxText = value;
    state = state;
    sendUpdateScoreboard();
  }

  function setTeamName(teamNum, value) {
    if (!state) return;
    state["team" + teamNum].name = value;
    state = state;
    sendUpdateScoreboard();
  }

  function setBackgroundColor(teamNum, value) {
    if (!state) return;
    state["team" + teamNum].bgColor = value;
    state = state;
    sendUpdateScoreboard();
  }

  function setTextColor(teamNum, value) {
    if (!state) return;
    state["team" + teamNum].textColor = value;
    state = state;
    sendUpdateScoreboard();
  }

  function setSelectValue(tKey, key, value) {
    if (!state) return;
    state[tKey][key] = value;
    state = state;
    sendUpdateScoreboard();
  }

  // Confirm dialog
  let confirmMessage = $state("");
  let confirmResolve = $state(null);

  async function confirmDialog(message) {
    confirmMessage = message;
    return new Promise((resolve) => {
      confirmResolve = resolve;
      document.getElementById("confirm").showModal();
    });
  }

  function handleConfirmOk() {
    document.getElementById("confirm").close();
    if (confirmResolve) { confirmResolve(true); confirmResolve = null; }
  }

  function handleConfirmCancel() {
    document.getElementById("confirm").close();
    if (confirmResolve) { confirmResolve(false); confirmResolve = null; }
  }

  // Derived: secondary score display per team
  function getSecScore(teamKey) {
    if (!state) return "-";
    const team = state[teamKey];
    let secScore = team.secondaryScore || "-";
    if (state.global?.scoringMode === "tennis") {
      const p = state.global.period;
      secScore = team["secondaryScore" + p] || "0";
    }
    return secScore;
  }

  function getControls() {
    if (!state?.controls) return [];
    const result = [];
    const keys = CONTROL_ORDER.filter((k) => state.controls[k]);
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      if (key === "primaryScore") continue;
      const c = state.controls[key];
      if (c.type === "counter") {
        result.push({ type: "counter", key, c, paired: false });
      } else {
        // Try to pack with next
        const nextKey = keys.slice(i + 1).find((k) => {
          if (k === "primaryScore") return false;
          const nc = state.controls[k];
          return nc && (nc.type === "select" || nc.type === "toggleTeam" || nc.type === "cycle");
        });
        const nc = nextKey ? state.controls[nextKey] : null;
        const canPack =
          nc && (nc.type === "select" || nc.type === "toggleTeam" || nc.type === "cycle");
        if (
          canPack &&
          (c.type === "select" || c.type === "toggleTeam" || c.type === "cycle")
        ) {
          result.push({ type: "pair", key, c, key2: nextKey, c2: nc });
          i = keys.indexOf(nextKey);
        } else {
          result.push({ type: "single", key, c });
        }
      }
    }
    return result;
  }

  connect();
</script>

<div
  class="bg-zinc-950 text-zinc-100 font-sans p-1"
  onfocusin={(e) => (activeInputId = e.target.id)}
  onfocusout={() => (activeInputId = null)}
>
  <!-- Header -->
  <div class="flex items-center justify-between mb-1 gap-1">
    <div>
      <span id="stat" class="status-text {statusColor}">{statusText}</span>
    </div>
    <div class="flex gap-2 text-xs">
      <span id="si" class={syncColor}>{syncText}</span>
      <span id="sp">{battery}</span>
      <span id="sb">{bitrateText}</span>
    </div>
    <div class="flex gap-1">
      <a href="./" class="text-indigo-400 hover:text-indigo-300 text-xs">Home</a>
    </div>
  </div>

  <!-- Sport / Layout selectors -->
  {#if state}
    <div class="grid grid-cols-2 gap-1 mb-1">
      <div class="disp-sm bg-zinc-800">
        <select
          id="sport-selector"
          value={state.sportId || ""}
          onchange={(e) => switchSport(e.target.value)}
        >
          <option value="">CHANGE SPORT...</option>
          {#each sportNames as name}
            <option value={name}>{name.toUpperCase()}</option>
          {/each}
        </select>
      </div>
      <div class="disp-sm bg-zinc-800">
        <select
          id="layout-selector"
          value={state.layout || ""}
          onchange={(e) => switchLayout(e.target.value)}
        >
          <option value="">Layout...</option>
          <option value="standard">Standard</option>
          <option value="compact">Compact</option>
        </select>
      </div>
    </div>

    <!-- Global toggles -->
    <div class="grid grid-cols-4 gap-1 mb-1">
      <button
        id="btn-show-title"
        class="btn btn-top {state.global?.showTitle ? 'btn-active' : ''}"
        onclick={() => toggleButtonState("showTitle")}
      >
        TITLE
      </button>
      <button
        id="btn-show-clock"
        class="btn btn-top {state.global?.showClock ? 'btn-active' : ''}"
        onclick={() => toggleButtonState("showClock")}
      >
        CLOCK
      </button>
      <button
        id="btn-info-box"
        class="btn btn-top {state.global?.showStats ? 'btn-active' : ''}"
        onclick={() => toggleButtonState("showStats")}
      >
        INFO
      </button>
      <button
        id="btn-more-stats"
        class="btn btn-top {state.global?.showMoreStats ? 'btn-active' : ''}"
        onclick={() => toggleButtonState("showMoreStats")}
      >
        MORE
      </button>
    </div>

    <!-- Global inputs -->
    <div class="grid grid-cols-3 gap-1 mb-1">
      <div class="conf-input">
        <div class="conf-label">TITLE</div>
        <input
          id="title"
          type="text"
          value={state.global?.title || ""}
          onblur={(e) => setTitle(e.target.value)}
        />
      </div>
      <div class="conf-input">
        <div class="conf-label"><span id="lbl-period">{state.global?.periodLabel || "PER"}</span></div>
        <input
          id="period"
          type="text"
          value={state.global?.period || ""}
          onblur={(e) => setPeriod(e.target.value)}
        />
      </div>
      <div class="conf-input">
        <div class="conf-label">INFO</div>
        <input
          id="info-box"
          type="text"
          value={state.global?.infoBoxText || ""}
          onblur={(e) => setInfoBoxText(e.target.value)}
        />
      </div>
    </div>

    <!-- Clock -->
    <div id="clock-details" hidden={clockDetailsHidden} class="mb-1">
      <div class="grid grid-cols-4 gap-1 mb-1">
        <div class="conf-input">
          <div class="conf-label">CLOCK</div>
          <input
            id="clock"
            type="text"
            value={state.global?.timer || ""}
            onblur={(e) => setClock(e.target.value)}
          />
        </div>
        <div class="disp-sm bg-zinc-800">
          <select
            id="clock-direction"
            value={state.global?.timerDirection || "down"}
            onchange={(e) => setClockDirection(e.target.value)}
          >
            <option value="up">Up</option>
            <option value="down">Down</option>
          </select>
        </div>
        <div class="disp-sm bg-zinc-800">
          <select
            id="clock-maximum"
            value={String(state.global?.duration || 1)}
            onchange={(e) => setDuration(e.target.value)}
          >
            {#each clockMaximumOptions as min}
              <option value={String(min)}>{min} min</option>
            {/each}
          </select>
        </div>
        <button id="toggle-clock" class="btn btn-ctrl" onclick={sendToggleClock}>
          START/STOP
        </button>
      </div>
    </div>

    <!-- Historic scores (tennis sets) -->
    <div class="grid grid-cols-5 gap-1 mb-1" id="history-grid">
      {#each [1, 2, 3, 4, 5] as setNum}
        <div class="flex flex-col gap-1">
          <!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
          <div
            class="text-center text-[9px] text-zinc-500 border border-transparent rounded cursor-pointer hover:border-zinc-600 {state.global?.period == String(setNum) ? 'active-set border-yellow-600' : ''}"
            onclick={() => setHistoricPeriod(setNum)}
          >
            SET {setNum}
          </div>
          <div class="h-8 rounded bg-zinc-800 border border-zinc-700">
            <select
              value={state.team1?.["secondaryScore" + setNum] || ""}
              onchange={(e) => setHistoricScore(1, setNum, e.target.value)}
            >
              <option value="">-</option>
              {#each Array.from({ length: rangeCache.max + 1 }, (_, i) => i) as v}
                <option value={String(v)}>{v}</option>
              {/each}
            </select>
          </div>
          <div class="h-8 rounded bg-zinc-800 border border-zinc-700">
            <select
              value={state.team2?.["secondaryScore" + setNum] || ""}
              onchange={(e) => setHistoricScore(2, setNum, e.target.value)}
            >
              <option value="">-</option>
              {#each Array.from({ length: rangeCache.max + 1 }, (_, i) => i) as v}
                <option value={String(v)}>{v}</option>
              {/each}
            </select>
          </div>
        </div>
      {/each}
    </div>

    <!-- Team panels -->
    <div id="ctrl" class="grid grid-cols-2 gap-1">
      {#each [1, 2] as n}
        {@const tKey = "team" + n}
        {@const team = state[tKey]}
        {@const secScore = getSecScore(tKey)}
        {@const controls = getControls()}
        <div>
          <!-- Team header -->
          <div class="rounded-t p-1" style="background:{team.bgColor}">
            <input
              type="text"
              id="in-n-{n}"
              value={team.name}
              onblur={(e) => setTeamName(n, e.target.value)}
            />
          </div>
          <div class="card rounded-t-none">
            <!-- Score display + color pickers -->
            <div class="grid grid-cols-4 gap-1 h-10 mb-2">
              <div
                class="disp-box"
                style="background:{team.bgColor};color:{team.textColor}"
              >
                {team.primaryScore}
              </div>
              <div class="disp-box m-shadow" style="background:{team.bgColor};color:white">
                {secScore}
              </div>
              <div class="rounded border border-zinc-700 bg-zinc-800">
                <input
                  type="color"
                  value={team.bgColor}
                  oninput={(e) => setBackgroundColor(n, e.target.value)}
                />
              </div>
              <div class="rounded border border-zinc-700 bg-zinc-800">
                <input
                  type="color"
                  value={team.textColor}
                  oninput={(e) => setTextColor(n, e.target.value)}
                />
              </div>
            </div>

            <!-- Primary score buttons -->
            <div class="grid grid-cols-3 gap-1 mb-2">
              <button
                class="col-span-2 btn btn-score"
                onclick={() => adjust(n, "primaryScore", 1)}
              >
                +Pt
              </button>
              <button class="btn btn-score" onclick={() => adjust(n, "primaryScore", -1)}>
                -Pt
              </button>
            </div>

            <!-- Other controls -->
            {#each controls as ctrl}
              {#if ctrl.type === "counter"}
                <div class="grid grid-cols-2 gap-1 mb-1">
                  <button
                    class="btn btn-ctrl"
                    onclick={() => adjust(n, ctrl.key, 1)}
                  >
                    +{ctrl.c.label}
                  </button>
                  <button
                    class="btn btn-ctrl"
                    onclick={() => adjust(n, ctrl.key, -1)}
                  >
                    -{ctrl.c.label}
                  </button>
                </div>
              {:else if ctrl.type === "pair"}
                <div class="grid grid-cols-2 gap-1 mb-1">
                  {@render controlWidget(n, tKey, team, ctrl.key, ctrl.c)}
                  {@render controlWidget(n, tKey, team, ctrl.key2, ctrl.c2)}
                </div>
              {:else if ctrl.type === "single"}
                <div class="mb-1">
                  {@render controlWidget(n, tKey, team, ctrl.key, ctrl.c)}
                </div>
              {/if}
            {/each}
          </div>
        </div>
      {/each}
    </div>

    <!-- Match control buttons -->
    <div class="grid grid-cols-2 gap-1 mt-1">
      <button id="next-set" class="btn btn-ctrl" onclick={resetSet}>
        {state.global?.scoringMode === "tennis" ? "Start next set" : "Next set/period"}
      </button>
      <button id="new-match" class="btn btn-ctrl" onclick={newMatch}>
        New match
      </button>
    </div>
  {:else}
    <div class="text-center text-zinc-500 py-8">
      {statusText === "Disconnected" || statusText === "Reconnecting"
        ? statusText
        : "Waiting for scoreboard..."}
    </div>
  {/if}
</div>

<!-- Control widget snippet -->
{#snippet controlWidget(n, tKey, team, key, c)}
  {#if c.type === "select"}
    <div class="disp-sm bg-zinc-800">
      <select
        id="sel-{tKey}-{key}"
        value={team[key] || ""}
        onchange={(e) => setSelectValue(tKey, key, e.target.value)}
      >
        {#each c.options as v}
          <option value={v}>{c.label}: {v}</option>
        {/each}
      </select>
    </div>
  {:else if c.type === "toggleTeam"}
    <button
      class="btn btn-ctrl {team.possession ? 'btn-accent' : 'text-zinc-500'}"
      onclick={() => toggleTeam(n)}
    >
      {c.label}
    </button>
  {:else if c.type === "cycle"}
    {@const val = team[key] || "NONE"}
    {@const isActive = val && val !== "NONE" && !val.startsWith("NO ")}
    <button
      class="btn btn-ctrl {isActive ? 'btn-accent' : ''}"
      onclick={() => cycle(n, key)}
    >
      {c.label ? `${c.label}: ${val}` : val}
    </button>
  {/if}
{/snippet}

<!-- Confirm dialog -->
<dialog id="confirm" class="backdrop:bg-black/60 rounded-xl p-0">
  <form method="dialog" class="bg-zinc-900 text-zinc-100">
    <div class="p-2">
      <p class="text-zinc-300">{confirmMessage}</p>
    </div>
    <div class="bg-zinc-800/60 px-4 py-3 sm:px-5 flex items-center justify-end gap-2">
      <button
        type="button"
        class="px-3 py-1.5 rounded-md border border-zinc-700 text-zinc-300 hover:bg-zinc-800 cursor-pointer"
        onclick={handleConfirmOk}
      >
        OK
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
