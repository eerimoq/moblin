import { createSignal, For, Show, onMount, onCleanup } from "solid-js";
import { createStore } from "solid-js/store";
import { render } from "solid-js/web";
import {
  connectionStatus,
  EventData,
  ResponseData,
  ScoreboardControlDef,
  ScoreboardMatchConfig,
  RemoteControlScoreboardTeam,
  WebSocketConnection,
  confirmCancel,
  confirmOk,
  showConfirm,
  createScoreboardTeam,
} from "./utils.ts";
import { ConfirmDialog, ConnectingOverlay } from "./components.tsx";

interface ControlEntry {
  kind: "counter" | "single";
  key: string;
  c: ScoreboardControlDef;
}

interface PackedControlEntry {
  kind: "packed";
  key: string;
  c: ScoreboardControlDef;
  nextKey: string;
  nextC: ScoreboardControlDef;
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
  };
}

function App() {
  const [scoreboardState, setScoreboardState] = createStore<ScoreboardMatchConfig>({
    sportId: "",
    layout: "",
    team1: createScoreboardTeam(),
    team2: createScoreboardTeam(),
    global: emptyGlobal(),
    controls: {},
  });
  const [status, setStatus] = createSignal<string>(connectionStatus.connecting);
  const [sports, setSports] = createSignal<string[]>([]);
  const [batteryLevel, setBatteryLevel] = createSignal("");
  const [bitrateMessage, setBitrateMessage] = createSignal("");
  const [activeInputId, setActiveInputId] = createSignal<string | null>(null);
  const [confirmOpen, setConfirmOpen] = createSignal(false);
  const [confirmMessage, setConfirmMessage] = createSignal("");
  let statusIntervalId: ReturnType<typeof setInterval> | null = null;

  class RemoteConnection extends WebSocketConnection {
    onConnected(): void {
      this.sendGetScoreboardSports();
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

  function connected(): boolean {
    return status() == connectionStatus.connected;
  }

  function sendUpdateScoreboard(): void {
    connection.sendUpdateScoreboard(scoreboardState);
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

  function handleEventScoreboard(config: ScoreboardMatchConfig): void {
    setScoreboardState(config);
  }

  function adjust(teamNumber: number, key: string, delta: number): void {
    const teamKey = makeTeamKey(teamNumber);
    const team = getTeam(scoreboardState, teamNumber);
    if (scoreboardState.global.scoringMode === "tennis" && key === "primaryScore") {
      adjTennis(teamNumber, delta);
      return;
    }
    if (key === "currentSetScore") {
      const setNum = parseInt(scoreboardState.global.period) || 1;
      if (setNum >= 1 && setNum <= 5) {
        const actualKey = makeSecondaryScoreKey(setNum);
        const current = parseInt(team[actualKey] ?? "0") || 0;
        const newVal = Math.max(0, current + delta).toString();
        setScoreboardState(teamKey, actualKey, newVal);
        const otherTeamKey = makeOtherTeamKey(teamNumber);
        const otherTeam = scoreboardState[otherTeamKey];
        if (!otherTeam[actualKey] || otherTeam[actualKey] === "") {
          setScoreboardState(otherTeamKey, actualKey, "0");
        }
      }
      connection.sendUpdateScoreboard(scoreboardState);
      return;
    }
    const current = parseInt(team[key] as string) || 0;
    const newVal = Math.max(0, current + delta).toString();
    setScoreboardState(teamKey as "team1" | "team2", key, newVal);
    if (key === "primaryScore" && delta > 0 && scoreboardState.global.changePossessionOnScore) {
      toggleTeam(teamNumber);
    }
    sendUpdateScoreboard();
  }

  function adjTennis(teamNumber: number, delta: number): void {
    const teamKey = makeTeamKey(teamNumber);
    const otherTeamKey = makeOtherTeamKey(teamNumber);
    let score = scoreboardState[teamKey].primaryScore;
    let otherScore = scoreboardState[otherTeamKey].primaryScore;
    if (delta > 0) {
      switch (score) {
        case "0":
          score = "15";
          break;
        case "15":
          score = "30";
          break;
        case "30":
          if (otherScore === "40") {
            score = "D";
            setScoreboardState(otherTeamKey, "primaryScore", "D");
          } else {
            score = "40";
          }
          break;
        case "40":
          if (otherScore === "Ad") {
            score = "D";
            setScoreboardState(otherTeamKey, "primaryScore", "D");
          } else if (otherScore === "40" || otherScore === "D") {
            score = "Ad";
          } else {
            winGame(teamNumber);
            return;
          }
          break;
        case "D":
          if (otherScore === "Ad") {
            setScoreboardState(otherTeamKey, "primaryScore", "D");
          } else {
            score = "Ad";
          }
          break;
        case "Ad":
          winGame(teamNumber);
          return;
      }
    } else {
      switch (score) {
        case "Ad":
          score = "D";
          break;
        case "D":
          score = "40";
          break;
        case "40":
          score = "30";
          break;
        case "30":
          score = "15";
          break;
        case "15":
          score = "0";
          break;
      }
    }
    setScoreboardState(teamKey, "primaryScore", score);
    sendUpdateScoreboard();
  }

  function winGame(teamNumber: number): void {
    setScoreboardState("team1", "primaryScore", "0");
    setScoreboardState("team2", "primaryScore", "0");
    const nextServer = scoreboardState.team1.possession ? 2 : 1;
    setScoreboardState("team1", "possession", nextServer === 1);
    setScoreboardState("team2", "possession", nextServer === 2);
    adjust(teamNumber, "currentSetScore", 1);
  }

  function toggleTeam(teamNumber: number): void {
    setScoreboardState("team1", "possession", teamNumber === 1);
    setScoreboardState("team2", "possession", teamNumber === 2);
    sendUpdateScoreboard();
  }

  function setTeamName(teamNumber: number, name: string): void {
    setScoreboardState(makeTeamKey(teamNumber), "name", name);
    sendUpdateScoreboard();
  }

  function setHistoricScore(teamNumber: number, idx: number, score: string): void {
    const teamKey = makeTeamKey(teamNumber);
    const actualKey = makeSecondaryScoreKey(idx);
    setScoreboardState(teamKey, actualKey, score);
    if (score !== "") {
      const otherTeamKey = makeOtherTeamKey(teamNumber);
      const otherTeam = scoreboardState[otherTeamKey];
      if (!otherTeam[actualKey] || otherTeam[actualKey] === "") {
        setScoreboardState(otherTeamKey, actualKey, "0");
      }
    }
    sendUpdateScoreboard();
  }

  function setHistoricPeriod(period: number): void {
    setScoreboardState("global", "period", period.toString());
    sendUpdateScoreboard();
  }

  function cycle(teamNumber: number, key: string): void {
    const teamKey = makeTeamKey(teamNumber);
    const control = scoreboardState.controls[key];
    if (!control || !control.options) return;
    const team = scoreboardState[teamKey];
    const current = (team[key] as string) || "";
    const idx = control.options.indexOf(current);
    const next = control.options[(idx + 1) % control.options.length];
    setScoreboardState(teamKey, key, next);
    sendUpdateScoreboard();
  }

  function switchSport(sportId: string): void {
    if (!sportId) return;
    connection.sendSetScoreboardSport(sportId);
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

  function setBackgroundColor(teamNumber: number, color: string): void {
    setScoreboardState(makeTeamKey(teamNumber), "bgColor", color);
    sendUpdateScoreboard();
  }

  function setTextColor(teamNumbar: number, color: string): void {
    setScoreboardState(makeTeamKey(teamNumbar), "textColor", color);
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
      const key = makeSecondaryScoreKey(setIndex);
      if (!scoreboardState.team1[key] && !scoreboardState.team2[key]) {
        slot = setIndex;
        break;
      }
    }
    if (slot !== -1) {
      const t1Score = scoreboardState.team1.primaryScore;
      const t2Score = scoreboardState.team2.primaryScore;
      const secondaryScoreKey = makeSecondaryScoreKey(slot);
      setScoreboardState("team1", secondaryScoreKey, t1Score);
      setScoreboardState("team2", secondaryScoreKey, t2Score);
      if (t1Score && !t2Score) setScoreboardState("team2", secondaryScoreKey, "0");
      if (t2Score && !t1Score) setScoreboardState("team1", secondaryScoreKey, "0");
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
      const secondaryScoreKey = makeSecondaryScoreKey(setIndex);
      setScoreboardState("team1", secondaryScoreKey, "");
      setScoreboardState("team2", secondaryScoreKey, "");
    }
    sendUpdateScoreboard();
  }

  function setSelectControl(teamNumbar: number, key: string, value: string): void {
    setScoreboardState(makeTeamKey(teamNumbar), key, value);
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
              onClick={() => connection.sendToggleClock()}
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
                connection.sendSetScoreboardClock(event.target.value);
              }}
            />
            <select
              class="btn-top bg-black rounded"
              value={scoreboardState.global.duration}
              onChange={(event) => connection.setScoreboardDuration(parseInt(event.target.value))}
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
                <TeamScorePicker
                  setNumber={setNumber}
                  team={scoreboardState.team1}
                  onChange={(value) => setHistoricScore(1, setNumber, value)}
                />
                <TeamScorePicker
                  setNumber={setNumber}
                  team={scoreboardState.team2}
                  onChange={(value) => setHistoricScore(2, setNumber, value)}
                />
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
      <ConnectingOverlay status={status} />
    </>
  );
}

interface TeamColumnProps {
  teamNumber: number;
  state: ScoreboardMatchConfig;
  onAdjust: (teamNumber: number, key: string, delta: number) => void;
  onCycle: (teamNumber: number, key: string) => void;
  onToggle: (teamNumber: number) => void;
  onSelectControl: (teamNumber: number, key: string, value: string) => void;
  onNameChange: (teamNumber: number, name: string) => void;
  onBgColor: (teamNumber: number, color: string) => void;
  onTextColor: (teamNumber: number, color: string) => void;
}

function makeTeamKey(teamNumber: number): "team1" | "team2" {
  return `team${teamNumber}` as "team1" | "team2";
}

function makeOtherTeamKey(teamNumber: number): "team1" | "team2" {
  return makeTeamKey(teamNumber === 1 ? 2 : 1);
}

type SecondaryScoreKey =
  | "secondaryScore1"
  | "secondaryScore2"
  | "secondaryScore3"
  | "secondaryScore4"
  | "secondaryScore5";

function makeSecondaryScoreKey(scoreNumber: number): SecondaryScoreKey {
  return `secondaryScore${scoreNumber}` as SecondaryScoreKey;
}

function getTeam(state: ScoreboardMatchConfig, teamNumber: number): RemoteControlScoreboardTeam {
  return state[makeTeamKey(teamNumber)];
}

function TeamColumn(props: TeamColumnProps) {
  const team = () => getTeam(props.state, props.teamNumber);

  const secScore = () => {
    if (props.state.global.scoringMode === "tennis") {
      return team()[makeSecondaryScoreKey(parseInt(props.state.global.period))] || "0";
    }
    return team().secondaryScore || "-";
  };

  const controls = (): AnyControlEntry[] => {
    const result: AnyControlEntry[] = [];
    const ctrl = props.state.controls;
    if (!ctrl) return result;
    for (let orderIndex = 0; orderIndex < CONTROL_ORDER.length; orderIndex++) {
      const key = CONTROL_ORDER[orderIndex];
      const control = ctrl[key];
      if (!control || key === "primaryScore") continue;
      if (control.type === "counter") {
        result.push({ kind: "counter", key, c: control });
      } else {
        let nextKey: string | null = null;
        let nextControl: ScoreboardControlDef | null = null;
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
          onBlur={(event) => props.onNameChange(props.teamNumber, event.target.value)}
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
              onInput={(event) => props.onBgColor(props.teamNumber, event.target.value)}
            />
          </div>
          <div class="rounded border border-zinc-700 bg-zinc-800">
            <input
              type="color"
              value={team().textColor}
              onInput={(event) => props.onTextColor(props.teamNumber, event.target.value)}
            />
          </div>
        </div>
        <div class="grid grid-cols-3 gap-1 mb-2">
          <button
            class="col-span-2 btn btn-score"
            onClick={() => props.onAdjust(props.teamNumber, "primaryScore", 1)}
          >
            +Pt
          </button>
          <button
            class="col-span-1 btn btn-score"
            onClick={() => props.onAdjust(props.teamNumber, "primaryScore", -1)}
          >
            -Pt
          </button>
        </div>
        <For each={controls()}>
          {(ctrl) => {
            if (ctrl.kind === "counter") {
              return (
                <div class="grid grid-cols-2 gap-1 mb-1">
                  <button
                    class="btn btn-ctrl"
                    onClick={() => props.onAdjust(props.teamNumber, ctrl.key, 1)}
                  >
                    +{ctrl.c.label}
                  </button>
                  <button
                    class="btn btn-ctrl"
                    onClick={() => props.onAdjust(props.teamNumber, ctrl.key, -1)}
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
                    teamNumber={props.teamNumber}
                    controlKey={ctrl.key}
                    control={ctrl.c}
                    team={team()}
                    onCycle={props.onCycle}
                    onToggle={props.onToggle}
                    onSelect={props.onSelectControl}
                  />
                  <ControlWidget
                    teamNumber={props.teamNumber}
                    controlKey={ctrl.nextKey}
                    control={ctrl.nextC}
                    team={team()}
                    onCycle={props.onCycle}
                    onToggle={props.onToggle}
                    onSelect={props.onSelectControl}
                  />
                </div>
              );
            }
            return (
              <div class="mb-1">
                <ControlWidget
                  teamNumber={props.teamNumber}
                  controlKey={ctrl.key}
                  control={ctrl.c}
                  team={team()}
                  onCycle={props.onCycle}
                  onToggle={props.onToggle}
                  onSelect={props.onSelectControl}
                />
              </div>
            );
          }}
        </For>
      </div>
    );
  }
  return (
    <div class="flex-1 space-y-2" id={`t${props.teamNumber}a`}>
      <Name />
      <Controls />
    </div>
  );
}

interface ControlWidgetProps {
  teamNumber: number;
  controlKey: string;
  control: ScoreboardControlDef;
  team: RemoteControlScoreboardTeam;
  onCycle: (teamNumber: number, key: string) => void;
  onToggle: (teamNumber: number) => void;
  onSelect: (teamNumber: number, key: string, value: string) => void;
}

function ControlWidget({
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

interface TeamScorePickerProps {
  setNumber: number;
  team: RemoteControlScoreboardTeam;
  onChange: (value: string) => void;
}

function TeamScorePicker(props: TeamScorePickerProps) {
  return (
    <div class="h-8 rounded bg-zinc-800 border border-zinc-700">
      <select
        value={props.team[makeSecondaryScoreKey(props.setNumber)] ?? ""}
        onChange={(event) => props.onChange(event.target.value)}
      >
        <option value="">-</option>
        <For each={Array.from({ length: 31 }, (_, scoreValue) => scoreValue)}>
          {(scoreValue) => <option value={String(scoreValue)}>{scoreValue}</option>}
        </For>
      </select>
    </div>
  );
}

render(() => <App />, document.getElementById("app")!);
