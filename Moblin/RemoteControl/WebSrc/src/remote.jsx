import { createSignal, For, Show, onMount, onCleanup } from "solid-js";
import { createStore } from "solid-js/store";
import { render } from "solid-js/web";
import { websocketUrl } from "./utils.js";

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

function emptyTeam() {
  return {
    name: "",
    bgColor: "#000000",
    textColor: "#ffffff",
    primaryScore: "0",
    secondaryScore: "0",
    secondaryScore1: "",
    secondaryScore2: "",
    secondaryScore3: "",
    secondaryScore4: "",
    secondaryScore5: "",
    stat1: "",
    stat2: "",
    stat3: "",
    stat4: "",
    possession: false,
  };
}

function emptyGlobal() {
  return {
    title: "",
    period: "1",
    periodLabel: "PER",
    timer: "",
    timerDirection: "countDown",
    duration: "",
    infoBoxText: "",
    scoringMode: "normal",
    showTitle: false,
    showStats: false,
    showMoreStats: false,
    showClock: false,
    changePossessionOnScore: false,
    maxSetScore: 30,
    minSetScore: 0,
  };
}

function App() {
  const [scoreboardState, setScoreboardState] = createStore({
    sportId: "",
    layout: "",
    team1: emptyTeam(),
    team2: emptyTeam(),
    global: emptyGlobal(),
    controls: {},
  });

  const [connected, setConnected] = createSignal(false);
  const [synced, setSynced] = createSignal(false);
  const [sports, setSports] = createSignal([]);
  const [batteryLevel, setBatteryLevel] = createSignal("");
  const [bitrateMessage, setBitrateMessage] = createSignal("");
  const [activeInputId, setActiveInputId] = createSignal(null);
  const [rangeMax, setRangeMax] = createSignal(30);
  const [rangeMin, setRangeMin] = createSignal(0);

  let ws = null;
  let requestId = 0;
  let statusIntervalId = null;

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

  function sendToggleClock() {
    sendRequest({ toggleScoreboardClock: {} });
  }

  function sendSetScoreboardClock(time) {
    sendRequest({ setScoreboardClock: { time } });
  }

  function sendUpdateScoreboard() {
    sendRequest({
      updateScoreboard: {
        config: {
          sportId: scoreboardState.sportId,
          layout: scoreboardState.layout,
          team1: scoreboardState.team1,
          team2: scoreboardState.team2,
          global: scoreboardState.global,
          controls: scoreboardState.controls,
        },
      },
    });
  }

  function handleEvent(event) {
    if (event.scoreboard !== undefined) {
      applyScoreboardState(event.scoreboard.config);
    }
  }

  function handleResponse(response) {
    if (response.data === undefined) return;
    if (response.data.getScoreboardSports !== undefined) {
      setSports(response.data.getScoreboardSports.names);
    } else if (response.data.getStatus !== undefined) {
      handleGetStatus(response.data.getStatus);
    }
  }

  function handleGetStatus(status) {
    if (status.general !== undefined) {
      setBatteryLevel(`${status.general.batteryLevel}%`);
    }
    if (status.topRight && status.topRight.bitrate !== undefined) {
      setBitrateMessage(status.topRight.bitrate.message);
    }
  }

  function applyScoreboardState(config) {
    setConnected(true);
    setSynced(true);
    const oldSportId = scoreboardState.sportId;
    setScoreboardState({
      sportId: config.sportId ?? scoreboardState.sportId,
      layout: config.layout ?? scoreboardState.layout,
      team1: { ...emptyTeam(), ...config.team1 },
      team2: { ...emptyTeam(), ...config.team2 },
      global: { ...emptyGlobal(), ...config.global },
      controls: config.controls ?? {},
    });
    if (config.global) {
      setRangeMin(config.global.minSetScore ?? 0);
      setRangeMax(config.global.maxSetScore ?? 30);
    }
    if (config.sportId !== oldSportId) {
      // Sport changed, controls layout may have changed
    }
  }

  function connect() {
    ws = new WebSocket(websocketUrl());
    ws.onopen = () => {
      sendRequest({ getScoreboardSports: {} });
      sendGetStatusRequest();
    };
    ws.onclose = () => {
      setConnected(false);
      setSynced(false);
      setTimeout(connect, 3000);
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

  function adjust(teamNum, key, delta) {
    const tKey = `team${teamNum}`;
    const t = scoreboardState[tKey];
    if (scoreboardState.global.scoringMode === "tennis" && key === "primaryScore") {
      adjTennis(teamNum, delta);
      return;
    }
    if (key === "currentSetScore") {
      const setNum = parseInt(scoreboardState.global.period) || 1;
      if (setNum >= 1 && setNum <= 5) {
        const actualKey = `secondaryScore${setNum}`;
        const current = parseInt(t[actualKey]) || 0;
        const newVal = Math.max(0, current + delta).toString();
        setScoreboardState(tKey, actualKey, newVal);
        const opp = teamNum === 1 ? "team2" : "team1";
        if (!scoreboardState[opp][actualKey] || scoreboardState[opp][actualKey] === "") {
          setScoreboardState(opp, actualKey, "0");
        }
      }
      sendUpdateScoreboard();
      return;
    }
    const current = parseInt(t[key]) || 0;
    const newVal = Math.max(0, current + delta).toString();
    setScoreboardState(tKey, key, newVal);
    if (key === "primaryScore" && delta > 0 && scoreboardState.global.changePossessionOnScore) {
      toggleTeam(teamNum);
    }
    sendUpdateScoreboard();
  }

  function adjTennis(teamNum, delta) {
    const tKey = `team${teamNum}`;
    const oKey = teamNum === 1 ? "team2" : "team1";
    let val = scoreboardState[tKey].primaryScore;
    let oppVal = scoreboardState[oKey].primaryScore;

    if (delta > 0) {
      switch (val) {
        case "0":
          val = "15";
          break;
        case "15":
          val = "30";
          break;
        case "30":
          if (oppVal === "40") {
            val = "D";
            setScoreboardState(oKey, "primaryScore", "D");
          } else {
            val = "40";
          }
          break;
        case "40":
          if (oppVal === "Ad") {
            val = "D";
            setScoreboardState(oKey, "primaryScore", "D");
          } else if (oppVal === "40" || oppVal === "D") {
            val = "Ad";
          } else {
            winGame(teamNum);
            return;
          }
          break;
        case "D":
          if (oppVal === "Ad") {
            setScoreboardState(oKey, "primaryScore", "D");
          } else {
            val = "Ad";
          }
          break;
        case "Ad":
          winGame(teamNum);
          return;
      }
    } else {
      switch (val) {
        case "Ad":
          val = "D";
          break;
        case "D":
          val = "40";
          break;
        case "40":
          val = "30";
          break;
        case "30":
          val = "15";
          break;
        case "15":
          val = "0";
          break;
      }
    }
    setScoreboardState(tKey, "primaryScore", val);
    sendUpdateScoreboard();
  }

  function winGame(teamNum) {
    const tKey = `team${teamNum}`;
    const oKey = teamNum === 1 ? "team2" : "team1";
    const setNum = parseInt(scoreboardState.global.period) || 1;
    const actualKey = `secondaryScore${setNum}`;
    const current = parseInt(scoreboardState[tKey][actualKey]) || 0;
    setScoreboardState(tKey, actualKey, (current + 1).toString());
    if (!scoreboardState[oKey][actualKey] || scoreboardState[oKey][actualKey] === "") {
      setScoreboardState(oKey, actualKey, "0");
    }
    setScoreboardState("team1", "primaryScore", "0");
    setScoreboardState("team2", "primaryScore", "0");
    sendUpdateScoreboard();
  }

  function toggleTeam(teamNum) {
    const opp = teamNum === 1 ? 2 : 1;
    setScoreboardState("team1", "possession", teamNum === 1);
    setScoreboardState("team2", "possession", teamNum === 2);
    sendUpdateScoreboard();
  }

  function setTeamName(teamNum, name) {
    setScoreboardState(`team${teamNum}`, "name", name);
    sendUpdateScoreboard();
  }

  function setHistoricScore(teamNum, idx, score) {
    const tKey = `team${teamNum}`;
    const actualKey = `secondaryScore${idx}`;
    setScoreboardState(tKey, actualKey, score);
    if (score !== "") {
      const opp = teamNum === 1 ? "team2" : "team1";
      if (!scoreboardState[opp][actualKey] || scoreboardState[opp][actualKey] === "") {
        setScoreboardState(opp, actualKey, "0");
      }
    }
    sendUpdateScoreboard();
  }

  function setHistoricPeriod(period) {
    setScoreboardState("global", "period", period.toString());
    sendUpdateScoreboard();
  }

  function cycle(teamNum, key) {
    const tKey = `team${teamNum}`;
    const c = scoreboardState.controls[key];
    if (!c || !c.options) return;
    const current = scoreboardState[tKey][key] || "";
    const idx = c.options.indexOf(current);
    const next = c.options[(idx + 1) % c.options.length];
    setScoreboardState(tKey, key, next);
    sendUpdateScoreboard();
  }

  function switchSport(sportId) {
    if (!sportId) return;
    sendRequest({ setScoreboardSport: { sportId } });
  }

  function switchLayout(layout) {
    if (!layout) return;
    setScoreboardState("layout", layout);
    sendUpdateScoreboard();
  }

  function toggleGlobal(key) {
    setScoreboardState("global", key, !scoreboardState.global[key]);
    sendUpdateScoreboard();
  }

  function setClockDirection(direction) {
    setScoreboardState("global", "timerDirection", direction);
    sendUpdateScoreboard();
  }

  function setTitle(title) {
    setScoreboardState("global", "title", title);
    sendUpdateScoreboard();
  }

  function setPeriod(period) {
    setScoreboardState("global", "period", period);
    sendUpdateScoreboard();
  }

  function setInfoBoxText(text) {
    setScoreboardState("global", "infoBoxText", text);
    sendUpdateScoreboard();
  }

  function setBackgroundColor(teamNum, color) {
    setScoreboardState(`team${teamNum}`, "bgColor", color);
    sendUpdateScoreboard();
  }

  function setTextColor(teamNum, color) {
    setScoreboardState(`team${teamNum}`, "textColor", color);
    sendUpdateScoreboard();
  }

  function nextSet() {
    const period = parseInt(scoreboardState.global.period) || 1;
    setScoreboardState("global", "period", (period + 1).toString());
    sendUpdateScoreboard();
  }

  function newMatch() {
    setScoreboardState({
      ...scoreboardState,
      team1: { ...scoreboardState.team1, primaryScore: "0", secondaryScore: "0" },
      team2: { ...scoreboardState.team2, primaryScore: "0", secondaryScore: "0" },
      global: { ...scoreboardState.global, period: "1", timer: "" },
    });
    sendUpdateScoreboard();
  }

  function setSelectControl(teamNum, key, value) {
    setScoreboardState(`team${teamNum}`, key, value);
    sendUpdateScoreboard();
  }

  onMount(() => {
    connect();
    statusIntervalId = setInterval(sendGetStatusRequest, 2000);
  });

  onCleanup(() => {
    if (statusIntervalId) clearInterval(statusIntervalId);
    if (ws) ws.close();
  });

  return (
    <div>
      {/* Status bar */}
      <div class="flex justify-between items-center mb-2">
        <div class="flex gap-4 text-xs text-zinc-400">
          <span>{batteryLevel()}</span>
          <span>{bitrateMessage()}</span>
        </div>
        <div class="text-xs">
          <Show when={connected() && synced()}>
            <span class="text-green-500 status-text">SYNCED</span>
          </Show>
          <Show when={!connected()}>
            <span class="text-red-500 status-text">Disconnected</span>
          </Show>
        </div>
      </div>

      {/* Sport & Layout selectors */}
      <div class="flex gap-2 mb-2">
        <div class="disp-sm flex-1 bg-zinc-800">
          <select
            class="text-sm"
            value={scoreboardState.sportId}
            onChange={(e) => switchSport(e.target.value)}
          >
            <option value="">CHANGE SPORT...</option>
            <For each={sports()}>
              {(s) => <option value={s}>{s.toUpperCase()}</option>}
            </For>
          </select>
        </div>
        <div class="disp-sm flex-1 bg-zinc-800">
          <select
            class="text-sm"
            value={scoreboardState.layout}
            onChange={(e) => switchLayout(e.target.value)}
          >
            <option value="">Layout...</option>
            <option value="normal">Normal</option>
            <option value="compact">Compact</option>
          </select>
        </div>
      </div>

      {/* Main controls - wrapped in opacity container */}
      <div classList={{ "opacity-30 pointer-events-none": !connected() }}>
        {/* Team columns */}
        <div class="flex gap-1 mb-2">
          <For each={[1, 2]}>
            {(n) => (
              <TeamColumn
                n={n}
                state={scoreboardState}
                onAdjust={adjust}
                onCycle={cycle}
                onToggle={toggleTeam}
                onSelectControl={setSelectControl}
                onNameChange={setTeamName}
                onBgColor={setBackgroundColor}
                onTextColor={setTextColor}
              />
            )}
          </For>
        </div>

        {/* Historic scores */}
        <div class="card mb-2">
          <div class="flex gap-1" id="history-grid">
            <For each={[1, 2, 3, 4, 5]}>
              {(i) => (
                <div class="flex flex-col gap-1 flex-1">
                  <div
                    class="text-center text-[9px] text-zinc-500 border border-transparent rounded cursor-pointer hover:border-zinc-600"
                    classList={{
                      "active-set border-yellow-600":
                        scoreboardState.global.period === String(i),
                    }}
                    onClick={() => setHistoricPeriod(i)}
                  >
                    SET {i}
                  </div>
                  <div class="h-8 rounded bg-zinc-800 border border-zinc-700">
                    <select
                      value={scoreboardState.team1[`secondaryScore${i}`] || ""}
                      onChange={(e) => setHistoricScore(1, i, e.target.value)}
                    >
                      <option value="">-</option>
                      <For each={Array.from({ length: rangeMax() + 1 }, (_, v) => v)}>
                        {(v) => <option value={String(v)}>{v}</option>}
                      </For>
                    </select>
                  </div>
                  <div class="h-8 rounded bg-zinc-800 border border-zinc-700">
                    <select
                      value={scoreboardState.team2[`secondaryScore${i}`] || ""}
                      onChange={(e) => setHistoricScore(2, i, e.target.value)}
                    >
                      <option value="">-</option>
                      <For each={Array.from({ length: rangeMax() + 1 }, (_, v) => v)}>
                        {(v) => <option value={String(v)}>{v}</option>}
                      </For>
                    </select>
                  </div>
                </div>
              )}
            </For>
          </div>
        </div>

        {/* Global toggles */}
        <div class="grid grid-cols-4 gap-1 mb-2">
          <button
            class="btn btn-top"
            classList={{ "btn-active": scoreboardState.global.showTitle }}
            onClick={() => toggleGlobal("showTitle")}
          >
            TITLE
          </button>
          <button
            class="btn btn-top"
            classList={{ "btn-active": scoreboardState.global.showStats }}
            onClick={() => toggleGlobal("showStats")}
          >
            INFO BOX
          </button>
          <button
            class="btn btn-top"
            classList={{ "btn-active": scoreboardState.global.showMoreStats }}
            onClick={() => toggleGlobal("showMoreStats")}
          >
            MORE STATS
          </button>
          <button
            class="btn btn-top"
            classList={{ "btn-active": scoreboardState.global.showClock }}
            onClick={() => toggleGlobal("showClock")}
          >
            CLOCK
          </button>
        </div>

        {/* Title, period, info box */}
        <div class="card mb-2 space-y-1">
          <div class="flex gap-1">
            <div class="conf-label w-16 shrink-0">TITLE</div>
            <div class="conf-input flex-1">
              <input
                type="text"
                value={scoreboardState.global.title}
                onFocus={() => setActiveInputId("title")}
                onBlur={(e) => {
                  setActiveInputId(null);
                  setTitle(e.target.value);
                }}
                onChange={(e) => {
                  if (activeInputId() === "title") setTitle(e.target.value);
                }}
              />
            </div>
          </div>
          <div class="flex gap-1">
            <div class="conf-label w-16 shrink-0">
              {scoreboardState.global.periodLabel || "PER"}
            </div>
            <div class="conf-input flex-1">
              <input
                type="text"
                value={scoreboardState.global.period}
                onFocus={() => setActiveInputId("period")}
                onBlur={(e) => {
                  setActiveInputId(null);
                  setPeriod(e.target.value);
                }}
                onChange={(e) => {
                  if (activeInputId() === "period") setPeriod(e.target.value);
                }}
              />
            </div>
          </div>
          <div class="flex gap-1">
            <div class="conf-label w-16 shrink-0">INFO</div>
            <div class="conf-input flex-1">
              <input
                type="text"
                value={scoreboardState.global.infoBoxText}
                onFocus={() => setActiveInputId("info-box")}
                onBlur={(e) => {
                  setActiveInputId(null);
                  setInfoBoxText(e.target.value);
                }}
                onChange={(e) => {
                  if (activeInputId() === "info-box") setInfoBoxText(e.target.value);
                }}
              />
            </div>
          </div>
        </div>

        {/* Clock controls */}
        <Show when={scoreboardState.global.showClock}>
          <div class="card mb-2 space-y-1">
            <div class="flex gap-1">
              <button class="btn btn-ctrl flex-1" onClick={sendToggleClock}>
                START/STOP
              </button>
              <div class="conf-input flex-1">
                <input
                  type="text"
                  value={scoreboardState.global.timer}
                  placeholder="mm:ss"
                  onFocus={() => setActiveInputId("clock")}
                  onBlur={(e) => {
                    setActiveInputId(null);
                    sendSetScoreboardClock(e.target.value);
                  }}
                />
              </div>
            </div>
            <div class="flex gap-1">
              <div class="disp-sm flex-1 bg-zinc-800">
                <select
                  value={scoreboardState.global.timerDirection}
                  onChange={(e) => setClockDirection(e.target.value)}
                >
                  <option value="countDown">Count Down</option>
                  <option value="countUp">Count Up</option>
                </select>
              </div>
              <div class="conf-input flex-1">
                <input
                  type="number"
                  placeholder="Max min"
                  value={scoreboardState.global.duration}
                  onChange={(e) => {
                    sendRequest({
                      setScoreboardDuration: { minutes: parseInt(e.target.value) },
                    });
                  }}
                />
              </div>
            </div>
          </div>
        </Show>

        {/* Next set / New match */}
        <div class="grid grid-cols-2 gap-1 mb-2">
          <button class="btn btn-ctrl" onClick={nextSet}>
            {scoreboardState.global.scoringMode === "tennis"
              ? "Start next set"
              : "Next set/period"}
          </button>
          <button class="btn btn-ctrl" onClick={newMatch}>
            New match
          </button>
        </div>
      </div>

      {/* Status indicator */}
      <div class="text-center mt-2">
        <Show when={!connected()}>
          <span class="text-red-500 text-xs">Reconnecting...</span>
        </Show>
      </div>
    </div>
  );
}

function TeamColumn({ n, state, onAdjust, onCycle, onToggle, onSelectControl, onNameChange, onBgColor, onTextColor }) {
  const tKey = () => `team${n}`;
  const team = () => state[tKey()];

  const secScore = () => {
    if (state.global.scoringMode === "tennis") {
      const p = state.global.period;
      return team()[`secondaryScore${p}`] || "0";
    }
    return team().secondaryScore || "-";
  };

  const controls = () => {
    const result = [];
    const ctrl = state.controls;
    if (!ctrl) return result;

    for (let k = 0; k < CONTROL_ORDER.length; k++) {
      const key = CONTROL_ORDER[k];
      const c = ctrl[key];
      if (!c || key === "primaryScore") continue;

      if (c.type === "counter") {
        result.push({ kind: "counter", key, c });
      } else {
        // Try to pack two consecutive non-counter controls
        let nextKey = null;
        let nextC = null;
        for (let j = k + 1; j < CONTROL_ORDER.length; j++) {
          const nk = CONTROL_ORDER[j];
          const nc = ctrl[nk];
          if (nc && nk !== "primaryScore") {
            nextKey = nk;
            nextC = nc;
            break;
          }
        }
        const canPack =
          nextC &&
          (nextC.type === "select" ||
            nextC.type === "toggleTeam" ||
            nextC.type === "cycle");
        if (canPack) {
          result.push({ kind: "packed", key, c, nextKey, nextC });
          k = CONTROL_ORDER.indexOf(nextKey);
        } else {
          result.push({ kind: "single", key, c });
        }
      }
    }
    return result;
  };

  return (
    <div class="flex-1" id={`t${n}a`}>
      <div
        class="rounded-t p-1"
        style={{ background: team().bgColor }}
      >
        <input
          type="text"
          class=""
          value={team().name}
          style={{ color: team().textColor }}
          onBlur={(e) => onNameChange(n, e.target.value)}
        />
      </div>
      <div class="card rounded-t-none">
        <div class="grid grid-cols-4 gap-1 h-10 mb-2">
          <div
            class="disp-box"
            style={{ background: team().bgColor, color: team().textColor }}
          >
            {team().primaryScore}
          </div>
          <div
            class="disp-box m-shadow"
            style={{ background: team().bgColor, color: "white" }}
          >
            {secScore()}
          </div>
          <div class="rounded border border-zinc-700 bg-zinc-800">
            <input
              type="color"
              value={team().bgColor}
              onInput={(e) => onBgColor(n, e.target.value)}
            />
          </div>
          <div class="rounded border border-zinc-700 bg-zinc-800">
            <input
              type="color"
              value={team().textColor}
              onInput={(e) => onTextColor(n, e.target.value)}
            />
          </div>
        </div>

        {/* Primary score buttons */}
        <div class="grid grid-cols-3 gap-1 mb-2">
          <button
            class="col-span-2 btn btn-score"
            onClick={() => onAdjust(n, "primaryScore", 1)}
          >
            +Pt
          </button>
          <button
            class="col-span-1 btn btn-score"
            onClick={() => onAdjust(n, "primaryScore", -1)}
          >
            -Pt
          </button>
        </div>

        {/* Dynamic controls */}
        <For each={controls()}>
          {(ctrl) => {
            if (ctrl.kind === "counter") {
              return (
                <div class="grid grid-cols-2 gap-1 mb-1">
                  <button
                    class="btn btn-ctrl"
                    onClick={() => onAdjust(n, ctrl.key, 1)}
                  >
                    +{ctrl.c.label}
                  </button>
                  <button
                    class="btn btn-ctrl"
                    onClick={() => onAdjust(n, ctrl.key, -1)}
                  >
                    -{ctrl.c.label}
                  </button>
                </div>
              );
            }
            if (ctrl.kind === "packed") {
              return (
                <div class="grid grid-cols-2 gap-1 mb-1">
                  <ControlWidget
                    t={tKey()}
                    n={n}
                    k={ctrl.key}
                    c={ctrl.c}
                    team={team()}
                    onCycle={onCycle}
                    onToggle={onToggle}
                    onSelect={onSelectControl}
                  />
                  <ControlWidget
                    t={tKey()}
                    n={n}
                    k={ctrl.nextKey}
                    c={ctrl.nextC}
                    team={team()}
                    onCycle={onCycle}
                    onToggle={onToggle}
                    onSelect={onSelectControl}
                  />
                </div>
              );
            }
            // single
            return (
              <div class="mb-1">
                <ControlWidget
                  t={tKey()}
                  n={n}
                  k={ctrl.key}
                  c={ctrl.c}
                  team={team()}
                  onCycle={onCycle}
                  onToggle={onToggle}
                  onSelect={onSelectControl}
                />
              </div>
            );
          }}
        </For>
      </div>
    </div>
  );
}

function ControlWidget({ t, n, k, c, team, onCycle, onToggle, onSelect }) {
  if (c.type === "select") {
    return (
      <div class="disp-sm bg-zinc-800">
        <select
          value={team[k] || ""}
          onChange={(e) => onSelect(n, k, e.target.value)}
        >
          <For each={c.options || []}>
            {(v) => (
              <option value={v}>
                {c.label}: {v}
              </option>
            )}
          </For>
        </select>
      </div>
    );
  }
  if (c.type === "toggleTeam") {
    const isActive = () => team.possession === true;
    return (
      <button
        class="btn btn-ctrl"
        classList={{ "btn-accent": isActive(), "text-zinc-500": !isActive() }}
        onClick={() => onToggle(n)}
      >
        {c.label}
      </button>
    );
  }
  if (c.type === "cycle") {
    const val = () => team[k] || "";
    const isActive = () => {
      const v = val();
      return v && v !== "NONE" && !v.startsWith("NO ");
    };
    const label = () => (c.label ? `${c.label}: ${val()}` : val()) || "NONE";
    return (
      <button
        class="btn btn-ctrl"
        classList={{ "btn-accent": isActive() }}
        onClick={() => onCycle(n, k)}
      >
        {label()}
      </button>
    );
  }
  return null;
}

render(() => <App />, document.getElementById("app"));
