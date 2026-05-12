import { createSignal, For, Show, onMount, onCleanup } from "solid-js";
import { createStore } from "solid-js/store";
import { render } from "solid-js/web";
import {
  connectionStatus,
  EventData,
  ResponseData,
  ScoreboardControlDef,
  ScoreboardGlobalState,
  ScoreboardMatchConfig,
  ScoreboardTeamState,
  WebSocketConnection,
  confirmCancel,
  confirmOk,
  showConfirm,
} from "./utils.ts";
import { ConfirmDialog } from "./components.tsx";

type TeamState = ScoreboardTeamState;
type GlobalState = ScoreboardGlobalState;
type ControlDef = ScoreboardControlDef;
type ScoreboardState = ScoreboardMatchConfig;

interface ControlEntry {
  kind: "counter" | "single";
  key: string;
  c: ControlDef;
}

interface PackedControlEntry {
  kind: "packed";
  key: string;
  c: ControlDef;
  nextKey: string;
  nextC: ControlDef;
}

type AnyControlEntry = ControlEntry | PackedControlEntry;

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
  const [scoreboardState, setScoreboardState] = createStore<ScoreboardState>({
    sportId: "",
    layout: "",
    team1: emptyTeam(),
    team2: emptyTeam(),
    global: emptyGlobal(),
    controls: {},
  });
  const [status, setStatus] = createSignal<string>(connectionStatus.connecting);
  const [sports, setSports] = createSignal<string[]>([]);
  const [batteryLevel, setBatteryLevel] = createSignal("");
  const [bitrateMessage, setBitrateMessage] = createSignal("");
  const [activeInputId, setActiveInputId] = createSignal<string | null>(null);
  const [rangeMax, setRangeMax] = createSignal(30);
  const [_rangeMin, setRangeMin] = createSignal(0);
  const [confirmOpen, setConfirmOpen] = createSignal(false);
  const [confirmMessage, setConfirmMessage] = createSignal("");
  let statusIntervalId: ReturnType<typeof setInterval> | null = null;

  class RemoteConnection extends WebSocketConnection {
    onConnected(): void {
      this.sendRequest({ getScoreboardSports: {} });
      this.sendGetStatusRequest();
    }

    onStatusChanged(newStatus: string): void {
      setStatus(newStatus);
    }

    handleResponse(_id: number, result: { ok: boolean }, data?: ResponseData): void {
      if (!result.ok || data === undefined) return;
      if (data.getScoreboardSports !== undefined) {
        setSports(data.getScoreboardSports.names);
      } else if (data.getStatus !== undefined) {
        handleGetStatus(data.getStatus);
      }
    }

    handleEvent(data: EventData): void {
      if (data.scoreboard !== undefined) {
        handleEventScoreboard(data.scoreboard.config);
      }
    }
  }

  const connection = new RemoteConnection();

  function connected() {
    return status() == connectionStatus.connected;
  }

  function sendToggleClock() {
    connection.sendRequest({ toggleScoreboardClock: {} });
  }

  function sendSetScoreboardClock(time: string): void {
    connection.sendRequest({ setScoreboardClock: { time } });
  }

  function sendUpdateScoreboard() {
    connection.sendRequest({
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

  function handleGetStatus(status: Record<string, unknown>): void {
    const s = status as {
      general?: { batteryLevel: number };
      topRight?: { bitrate?: { message: string } };
    };
    if (s.general !== undefined) {
      setBatteryLevel(`${s.general.batteryLevel}%`);
    }
    if (s.topRight && s.topRight.bitrate !== undefined) {
      setBitrateMessage(s.topRight.bitrate.message);
    }
  }

  function handleEventScoreboard(config: Partial<ScoreboardState>): void {
    setScoreboardState({
      sportId: config.sportId,
      layout: config.layout,
      team1: { ...emptyTeam(), ...(config.team1 as TeamState) },
      team2: { ...emptyTeam(), ...(config.team2 as TeamState) },
      global: { ...emptyGlobal(), ...(config.global as GlobalState) },
      controls: (config.controls as Record<string, ControlDef>) ?? {},
    });
    if (config.global) {
      const g = config.global as GlobalState;
      setRangeMin((g.minSetScore as number) ?? 0);
      setRangeMax((g.maxSetScore as number) ?? 30);
    }
  }

  function adjust(teamNum: number, key: string, delta: number): void {
    const tKey = `team${teamNum}`;
    const team = scoreboardState[tKey] as TeamState;
    if (scoreboardState.global.scoringMode === "tennis" && key === "primaryScore") {
      adjTennis(teamNum, delta);
      return;
    }
    if (key === "currentSetScore") {
      const setNum = parseInt(scoreboardState.global.period) || 1;
      if (setNum >= 1 && setNum <= 5) {
        const actualKey = `secondaryScore${setNum}`;
        const current = parseInt(team[actualKey] as string) || 0;
        const newVal = Math.max(0, current + delta).toString();
        setScoreboardState(tKey as "team1" | "team2", actualKey, newVal);
        const opp = teamNum === 1 ? "team2" : "team1";
        const oppTeam = scoreboardState[opp] as TeamState;
        if (!oppTeam[actualKey] || oppTeam[actualKey] === "") {
          setScoreboardState(opp, actualKey, "0");
        }
      }
      sendUpdateScoreboard();
      return;
    }
    const current = parseInt(team[key] as string) || 0;
    const newVal = Math.max(0, current + delta).toString();
    setScoreboardState(tKey as "team1" | "team2", key, newVal);
    if (key === "primaryScore" && delta > 0 && scoreboardState.global.changePossessionOnScore) {
      toggleTeam(teamNum);
    }
    sendUpdateScoreboard();
  }

  function adjTennis(teamNum: number, delta: number): void {
    const tKey = `team${teamNum}` as "team1" | "team2";
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

  function winGame(teamNum: number): void {
    setScoreboardState("team1", "primaryScore", "0");
    setScoreboardState("team2", "primaryScore", "0");
    const nextServer = scoreboardState.team1.possession ? 2 : 1;
    setScoreboardState("team1", "possession", nextServer === 1);
    setScoreboardState("team2", "possession", nextServer === 2);
    adjust(teamNum, "currentSetScore", 1);
  }

  function toggleTeam(teamNum: number): void {
    setScoreboardState("team1", "possession", teamNum === 1);
    setScoreboardState("team2", "possession", teamNum === 2);
    sendUpdateScoreboard();
  }

  function setTeamName(teamNum: number, name: string): void {
    setScoreboardState(`team${teamNum}` as "team1" | "team2", "name", name);
    sendUpdateScoreboard();
  }

  function setHistoricScore(teamNum: number, idx: number, score: string): void {
    const tKey = `team${teamNum}` as "team1" | "team2";
    const actualKey = `secondaryScore${idx}`;
    setScoreboardState(tKey, actualKey, score);
    if (score !== "") {
      const opp = teamNum === 1 ? "team2" : "team1";
      const oppTeam = scoreboardState[opp] as TeamState;
      if (!oppTeam[actualKey] || oppTeam[actualKey] === "") {
        setScoreboardState(opp, actualKey, "0");
      }
    }
    sendUpdateScoreboard();
  }

  function setHistoricPeriod(period: number): void {
    setScoreboardState("global", "period", period.toString());
    sendUpdateScoreboard();
  }

  function cycle(teamNum: number, key: string): void {
    const tKey = `team${teamNum}` as "team1" | "team2";
    const control = scoreboardState.controls[key];
    if (!control || !control.options) return;
    const team = scoreboardState[tKey] as TeamState;
    const current = (team[key] as string) || "";
    const idx = control.options.indexOf(current);
    const next = control.options[(idx + 1) % control.options.length];
    setScoreboardState(tKey, key, next);
    sendUpdateScoreboard();
  }

  function switchSport(sportId: string): void {
    if (!sportId) return;
    connection.sendRequest({ setScoreboardSport: { sportId } });
  }

  function switchLayout(layout: string): void {
    if (!layout) return;
    setScoreboardState("layout", layout);
    sendUpdateScoreboard();
  }

  function toggleGlobal(key: string): void {
    setScoreboardState("global", key, !scoreboardState.global[key]);
    sendUpdateScoreboard();
  }

  function setClockDirection(direction: string): void {
    setScoreboardState("global", "timerDirection", direction);
    sendUpdateScoreboard();
  }

  function setTitle(title: string): void {
    setScoreboardState("global", "title", title);
    sendUpdateScoreboard();
  }

  function setPeriod(period: string): void {
    setScoreboardState("global", "period", period);
    sendUpdateScoreboard();
  }

  function setInfoBoxText(text: string): void {
    setScoreboardState("global", "infoBoxText", text);
    sendUpdateScoreboard();
  }

  function setBackgroundColor(teamNum: number, color: string): void {
    setScoreboardState(`team${teamNum}` as "team1" | "team2", "bgColor", color);
    sendUpdateScoreboard();
  }

  function setTextColor(teamNum: number, color: string): void {
    setScoreboardState(`team${teamNum}` as "team1" | "team2", "textColor", color);
    sendUpdateScoreboard();
  }

  async function nextSet() {
    if (scoreboardState.global.scoringMode === "tennis") {
      if (!(await showConfirm("Start next set?", setConfirmMessage, setConfirmOpen))) return;
      const period = parseInt(scoreboardState.global.period) || 0;
      setScoreboardState("global", "period", (period + 1).toString());
      setScoreboardState("team1", "primaryScore", "0");
      setScoreboardState("team2", "primaryScore", "0");
      sendUpdateScoreboard();
      return;
    }
    if (!(await showConfirm("Start next set/period?", setConfirmMessage, setConfirmOpen))) return;
    let slot = -1;
    for (let setIndex = 1; setIndex <= 5; setIndex++) {
      if (
        !scoreboardState.team1[`secondaryScore${setIndex}`] &&
        !scoreboardState.team2[`secondaryScore${setIndex}`]
      ) {
        slot = setIndex;
        break;
      }
    }
    if (slot !== -1) {
      const t1Score = scoreboardState.team1.primaryScore;
      const t2Score = scoreboardState.team2.primaryScore;
      setScoreboardState("team1", `secondaryScore${slot}`, t1Score);
      setScoreboardState("team2", `secondaryScore${slot}`, t2Score);
      if (t1Score && !t2Score) setScoreboardState("team2", `secondaryScore${slot}`, "0");
      if (t2Score && !t1Score) setScoreboardState("team1", `secondaryScore${slot}`, "0");
    }
    const period = parseInt(scoreboardState.global.period) || 0;
    setScoreboardState("global", "period", (period + 1).toString());
    Object.keys(scoreboardState.controls).forEach((controlKey) => {
      if (scoreboardState.controls[controlKey].periodReset) {
        const control = scoreboardState.controls[controlKey];
        if (control.type === "toggleTeam") {
          setScoreboardState("team1", controlKey, false);
          setScoreboardState("team2", controlKey, false);
          return;
        }
        const def = control.options && control.options.length > 0 ? control.options[0] : "0";
        setScoreboardState("team1", controlKey, def);
        setScoreboardState("team2", controlKey, def);
      }
    });
    if (scoreboardState.global.primaryScoreResetOnPeriod) {
      setScoreboardState("team1", "primaryScore", "0");
      setScoreboardState("team2", "primaryScore", "0");
    }
    if (scoreboardState.global.secondaryScoreResetOnPeriod) {
      setScoreboardState("team1", "secondaryScore", "0");
      setScoreboardState("team2", "secondaryScore", "0");
    }
    sendUpdateScoreboard();
  }

  async function newMatch() {
    if (
      !(await showConfirm(
        "Start new match? This clears scores and stats.",
        setConfirmMessage,
        setConfirmOpen,
      ))
    )
      return;
    if (scoreboardState.global.timerDirection === "up") {
      setScoreboardState("global", "timer", "0:00");
    } else {
      setScoreboardState("global", "timer", `${parseInt(scoreboardState.global.duration)}:00`);
    }
    setScoreboardState("global", "period", "1");
    Object.keys(scoreboardState.controls).forEach((controlKey) => {
      const control = scoreboardState.controls[controlKey];
      if (control.type === "toggleTeam") {
        setScoreboardState("team1", "possession", true);
        setScoreboardState("team2", "possession", false);
        return;
      }
      const def = control.options && control.options.length > 0 ? control.options[0] : "0";
      setScoreboardState("team1", controlKey, def);
      setScoreboardState("team2", controlKey, def);
    });
    setScoreboardState("team1", "primaryScore", "0");
    setScoreboardState("team2", "primaryScore", "0");
    const hasSec = !!scoreboardState.team1.secondaryScore;
    setScoreboardState("team1", "secondaryScore", hasSec ? "0" : "");
    setScoreboardState("team2", "secondaryScore", hasSec ? "0" : "");
    for (let setIndex = 1; setIndex <= 5; setIndex++) {
      setScoreboardState("team1", `secondaryScore${setIndex}`, "");
      setScoreboardState("team2", `secondaryScore${setIndex}`, "");
    }
    sendUpdateScoreboard();
  }

  function setSelectControl(teamNum: number, key: string, value: string): void {
    setScoreboardState(`team${teamNum}` as "team1" | "team2", key, value);
    sendUpdateScoreboard();
  }

  onMount(() => {
    statusIntervalId = setInterval(() => connection.sendGetStatusRequest(), 2000);
  });

  onCleanup(() => {
    if (statusIntervalId) clearInterval(statusIntervalId);
  });

  function Team() {
    return (
      <div class="flex gap-2" classList={{ "opacity-30 pointer-events-none": !connected() }}>
        <For each={[1, 2]}>
          {(teamNumber) => (
            <TeamColumn
              teamNumber={teamNumber}
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
    );
  }

  function Clock() {
    return (
      <Show when={scoreboardState.global.showClock}>
        <div>
          <div class="card grid grid-cols-4 gap-2 items-center shadow-xl">
            <button
              class="btn btn-top bg-indigo-600 text-white border-none"
              onClick={sendToggleClock}
            >
              Clock
            </button>
            <input
              type="text"
              placeholder="0:00"
              value={scoreboardState.global.timer}
              class="btn-top font-mono text-lg text-indigo-400 bg-black rounded"
              onFocus={() => setActiveInputId("clock")}
              onBlur={(event) => {
                setActiveInputId(null);
                sendSetScoreboardClock(event.target.value);
              }}
            />
            <select
              class="btn-top bg-black rounded"
              value={scoreboardState.global.duration}
              onChange={(event) =>
                connection.sendRequest({
                  setScoreboardDuration: { minutes: parseInt(event.target.value) },
                })
              }
            >
              <For each={Array.from({ length: 120 }, (_, minute) => minute + 1)}>
                {(minute) => <option value={minute}>{minute} min</option>}
              </For>
            </select>
            <select
              class="btn-top bg-black rounded"
              value={scoreboardState.global.timerDirection}
              onChange={(event) => setClockDirection(event.target.value)}
            >
              <option value="up">Up</option>
              <option value="down">Down</option>
            </select>
          </div>
        </div>
      </Show>
    );
  }

  function HistoricalScores() {
    return (
      <details>
        <summary>HISTORICAL SCORES</summary>
        <div class="grid grid-cols-5 gap-1 mt-1">
          <For each={[1, 2, 3, 4, 5]}>
            {(setNumber) => (
              <div class="flex flex-col gap-1">
                <div
                  class="text-center text-[9px] text-zinc-500 border border-transparent rounded cursor-pointer hover:border-zinc-600"
                  classList={{
                    "active-set border-yellow-600":
                      scoreboardState.global.period === String(setNumber),
                  }}
                  onClick={() => setHistoricPeriod(setNumber)}
                >
                  SET {setNumber}
                </div>
                <div class="h-8 rounded bg-zinc-800 border border-zinc-700">
                  <select
                    value={String(scoreboardState.team1[`secondaryScore${setNumber}`] ?? "")}
                    onChange={(event) => setHistoricScore(1, setNumber, event.target.value)}
                  >
                    <option value="">-</option>
                    <For
                      each={Array.from({ length: rangeMax() + 1 }, (_, scoreValue) => scoreValue)}
                    >
                      {(scoreValue) => <option value={String(scoreValue)}>{scoreValue}</option>}
                    </For>
                  </select>
                </div>
                <div class="h-8 rounded bg-zinc-800 border border-zinc-700">
                  <select
                    value={String(scoreboardState.team2[`secondaryScore${setNumber}`] ?? "")}
                    onChange={(event) => setHistoricScore(2, setNumber, event.target.value)}
                  >
                    <option value="">-</option>
                    <For
                      each={Array.from({ length: rangeMax() + 1 }, (_, scoreValue) => scoreValue)}
                    >
                      {(scoreValue) => <option value={String(scoreValue)}>{scoreValue}</option>}
                    </For>
                  </select>
                </div>
              </div>
            )}
          </For>
        </div>
      </details>
    );
  }

  function NewSetMatch() {
    return (
      <div class="grid grid-cols-2 gap-2">
        <button class="btn btn-ctrl border-zinc-600" onClick={nextSet}>
          {scoreboardState.global.scoringMode === "tennis" ? "Start next set" : "Next set/period"}
        </button>
        <button class="btn btn-ctrl border-red-900 text-red-400" onClick={newMatch}>
          New match
        </button>
      </div>
    );
  }

  function Configuration() {
    return (
      <details open>
        <summary>
          <span>SCOREBOARD CONFIGURATION</span>
          <span
            class="status-text"
            classList={{
              "text-green-500": connected(),
              "text-red-500": !connected(),
            }}
          >
            {connected() ? "Connected" : "Disconnected"}
          </span>
        </summary>
        <div class="card grid grid-cols-4 gap-2 mt-1">
          <Show when={sports().length > 0}>
            <select
              class="col-span-2 btn h-9 text-[10px] bg-black"
              value={scoreboardState.sportId}
              onChange={(event) => switchSport(event.target.value)}
            >
              <option value="">CHANGE SPORT...</option>
              <For each={sports()}>
                {(sportName) => <option value={sportName}>{sportName.toUpperCase()}</option>}
              </For>
            </select>
          </Show>
          <select
            class="col-span-2 btn h-9 text-[10px] bg-black"
            value={scoreboardState.layout}
            onChange={(event) => switchLayout(event.target.value)}
          >
            <option value="stacked">Stacked</option>
            <option value="stackedInline">Stacked inline</option>
            <option value="sideBySide">Side by side</option>
            <option value="stackHistory">Stack history</option>
          </select>

          <input
            type="text"
            placeholder="TITLE"
            class="col-span-2 conf-input px-2"
            value={scoreboardState.global.title}
            onFocus={() => setActiveInputId("title")}
            onBlur={(event) => {
              setActiveInputId(null);
              setTitle(event.target.value);
            }}
            onChange={(event) => {
              if (activeInputId() === "title") setTitle(event.target.value);
            }}
          />
          <div class="conf-label">{scoreboardState.global.periodLabel || "PER"}</div>
          <input
            type="text"
            class="conf-input"
            value={scoreboardState.global.period}
            onFocus={() => setActiveInputId("period")}
            onBlur={(event) => {
              setActiveInputId(null);
              setPeriod(event.target.value);
            }}
            onChange={(event) => {
              if (activeInputId() === "period") setPeriod(event.target.value);
            }}
          />
          <button
            class="btn h-9 text-[10px]"
            classList={{ "btn-active": scoreboardState.global.showTitle }}
            onClick={() => toggleGlobal("showTitle")}
          >
            Title
          </button>
          <button
            class="btn h-9 text-[10px]"
            classList={{ "btn-active": scoreboardState.global.showMoreStats }}
            onClick={() => toggleGlobal("showMoreStats")}
          >
            More stats
          </button>
          <button
            class="btn h-9 text-[10px]"
            classList={{ "btn-active": scoreboardState.global.showStats }}
            onClick={() => toggleGlobal("showStats")}
          >
            Info box
          </button>
          <input
            type="text"
            placeholder="INFO BOX"
            class="conf-input px-2"
            value={scoreboardState.global.infoBoxText}
            onFocus={() => setActiveInputId("info-box")}
            onBlur={(event) => {
              setActiveInputId(null);
              setInfoBoxText(event.target.value);
            }}
            onChange={(event) => {
              if (activeInputId() === "info-box") setInfoBoxText(event.target.value);
            }}
          />
          <button
            class="btn h-9 text-[10px]"
            classList={{ "btn-active": scoreboardState.global.showClock }}
            onClick={() => toggleGlobal("showClock")}
          >
            Clock
          </button>
        </div>
      </details>
    );
  }

  function Status() {
    return (
      <div class="btn-top border border-zinc-800 rounded font-mono text-xs flex items-center justify-center gap-4 text-zinc-500">
        <div>
          BIT: <span class="text-white">{bitrateMessage() || "--"}</span>
        </div>
        <div>
          BAT: <span class="text-white">{batteryLevel() || "--"}</span>
        </div>
      </div>
    );
  }

  return (
    <>
      <div class="h-full flex flex-col max-w-lg mx-auto space-y-2">
        <Team />
        <Clock />
        <HistoricalScores />
        <NewSetMatch />
        <Configuration />
        <Status />
      </div>
      <ConfirmDialog
        open={confirmOpen}
        message={confirmMessage}
        onOk={confirmOk}
        onCancel={confirmCancel}
        okTextClass="text-zinc-300"
      />
    </>
  );
}

interface TeamColumnProps {
  teamNumber: number;
  state: ScoreboardState;
  onAdjust: (teamNum: number, key: string, delta: number) => void;
  onCycle: (teamNum: number, key: string) => void;
  onToggle: (teamNum: number) => void;
  onSelectControl: (teamNum: number, key: string, value: string) => void;
  onNameChange: (teamNum: number, name: string) => void;
  onBgColor: (teamNum: number, color: string) => void;
  onTextColor: (teamNum: number, color: string) => void;
}

function TeamColumn({
  teamNumber,
  state,
  onAdjust,
  onCycle,
  onToggle,
  onSelectControl,
  onNameChange,
  onBgColor,
  onTextColor,
}: TeamColumnProps) {
  const tKey = () => `team${teamNumber}` as "team1" | "team2";

  const team = () => state[tKey()] as TeamState;

  const secScore = () => {
    if (state.global.scoringMode === "tennis") {
      const period = state.global.period;
      return (team()[`secondaryScore${period}`] as string) || "0";
    }
    return team().secondaryScore || "-";
  };

  const controls = (): AnyControlEntry[] => {
    const result: AnyControlEntry[] = [];
    const ctrl = state.controls;
    if (!ctrl) return result;

    for (let orderIndex = 0; orderIndex < CONTROL_ORDER.length; orderIndex++) {
      const key = CONTROL_ORDER[orderIndex];
      const control = ctrl[key];
      if (!control || key === "primaryScore") continue;

      if (control.type === "counter") {
        result.push({ kind: "counter", key, c: control });
      } else {
        // Try to pack two consecutive non-counter controls
        let nextKey: string | null = null;
        let nextControl: ControlDef | null = null;
        for (let searchIndex = orderIndex + 1; searchIndex < CONTROL_ORDER.length; searchIndex++) {
          const candidateKey = CONTROL_ORDER[searchIndex];
          const candidateControl = ctrl[candidateKey];
          if (candidateControl && candidateKey !== "primaryScore") {
            nextKey = candidateKey;
            nextControl = candidateControl;
            break;
          }
        }
        const canPack =
          nextControl &&
          (nextControl.type === "select" ||
            nextControl.type === "toggleTeam" ||
            nextControl.type === "cycle");
        if (canPack && nextKey && nextControl) {
          result.push({ kind: "packed", key, c: control, nextKey, nextC: nextControl });
          orderIndex = CONTROL_ORDER.indexOf(nextKey);
        } else {
          result.push({ kind: "single", key, c: control });
        }
      }
    }
    return result;
  };

  function Name() {
    return (
      <div class="rounded-t p-1" style={{ background: team().bgColor }}>
        <input
          type="text"
          class=""
          value={team().name}
          onBlur={(event) => onNameChange(teamNumber, event.target.value)}
        />
      </div>
    );
  }

  function Controls() {
    return (
      <div class="card rounded-t-none">
        <div class="grid grid-cols-4 gap-1 h-10 mb-2">
          <div class="disp-box" style={{ background: team().bgColor, color: team().textColor }}>
            {team().primaryScore}
          </div>
          <div class="disp-box m-shadow" style={{ background: team().bgColor, color: "white" }}>
            {secScore()}
          </div>
          <div class="rounded border border-zinc-700 bg-zinc-800">
            <input
              type="color"
              value={team().bgColor}
              onInput={(event) => onBgColor(teamNumber, event.target.value)}
            />
          </div>
          <div class="rounded border border-zinc-700 bg-zinc-800">
            <input
              type="color"
              value={team().textColor}
              onInput={(event) => onTextColor(teamNumber, event.target.value)}
            />
          </div>
        </div>
        <div class="grid grid-cols-3 gap-1 mb-2">
          <button
            class="col-span-2 btn btn-score"
            onClick={() => onAdjust(teamNumber, "primaryScore", 1)}
          >
            +Pt
          </button>
          <button
            class="col-span-1 btn btn-score"
            onClick={() => onAdjust(teamNumber, "primaryScore", -1)}
          >
            -Pt
          </button>
        </div>
        <For each={controls()}>
          {(ctrl) => {
            if (ctrl.kind === "counter") {
              return (
                <div class="grid grid-cols-2 gap-1 mb-1">
                  <button class="btn btn-ctrl" onClick={() => onAdjust(teamNumber, ctrl.key, 1)}>
                    +{ctrl.c.label}
                  </button>
                  <button class="btn btn-ctrl" onClick={() => onAdjust(teamNumber, ctrl.key, -1)}>
                    -{ctrl.c.label}
                  </button>
                </div>
              );
            }
            if (ctrl.kind === "packed") {
              return (
                <div class="grid grid-cols-2 gap-1 mb-1">
                  <ControlWidget
                    teamKey={tKey()}
                    teamNumber={teamNumber}
                    controlKey={ctrl.key}
                    control={ctrl.c}
                    team={team()}
                    onCycle={onCycle}
                    onToggle={onToggle}
                    onSelect={onSelectControl}
                  />
                  <ControlWidget
                    teamKey={tKey()}
                    teamNumber={teamNumber}
                    controlKey={ctrl.nextKey}
                    control={ctrl.nextC}
                    team={team()}
                    onCycle={onCycle}
                    onToggle={onToggle}
                    onSelect={onSelectControl}
                  />
                </div>
              );
            }
            return (
              <div class="mb-1">
                <ControlWidget
                  teamKey={tKey()}
                  teamNumber={teamNumber}
                  controlKey={ctrl.key}
                  control={ctrl.c}
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
    );
  }

  return (
    <div class="flex-1 space-y-2" id={`t${teamNumber}a`}>
      <Name />
      <Controls />
    </div>
  );
}

interface ControlWidgetProps {
  teamKey: string;
  teamNumber: number;
  controlKey: string;
  control: ControlDef;
  team: TeamState;
  onCycle: (teamNum: number, key: string) => void;
  onToggle: (teamNum: number) => void;
  onSelect: (teamNum: number, key: string, value: string) => void;
}

function ControlWidget({
  teamKey: _teamKey,
  teamNumber,
  controlKey,
  control,
  team,
  onCycle,
  onToggle,
  onSelect,
}: ControlWidgetProps) {
  if (control.type === "select") {
    return (
      <div class="disp-sm bg-zinc-800">
        <select
          value={(team[controlKey] as string) || ""}
          onChange={(event) => onSelect(teamNumber, controlKey, event.target.value)}
        >
          <For each={control.options || []}>
            {(optionValue) => (
              <option value={optionValue}>
                {control.label}: {optionValue}
              </option>
            )}
          </For>
        </select>
      </div>
    );
  }
  if (control.type === "toggleTeam") {
    const isActive = () => team.possession === true;
    return (
      <button
        class="btn btn-ctrl"
        classList={{ "btn-accent": isActive(), "text-zinc-500": !isActive() }}
        onClick={() => onToggle(teamNumber)}
      >
        {control.label}
      </button>
    );
  }
  if (control.type === "cycle") {
    const val = () => (team[controlKey] as string) || "";
    const isActive = () => {
      const currentVal = val();
      return !!(currentVal && currentVal !== "NONE" && !currentVal.startsWith("NO "));
    };
    const label = () => (control.label ? `${control.label}: ${val()}` : val()) || "NONE";
    return (
      <button
        class="btn btn-ctrl"
        classList={{ "btn-accent": isActive() }}
        onClick={() => onCycle(teamNumber, controlKey)}
      >
        {label()}
      </button>
    );
  }
  return null;
}

render(() => <App />, document.getElementById("app")!);
