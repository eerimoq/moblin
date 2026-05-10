import { createSignal, For, Match, Switch } from "solid-js";
import { createStore } from "solid-js/store";
import { render } from "solid-js/web";
import {
  WebSocketConnection,
  connectionStatus,
  showConfirm,
  confirmOk,
  confirmCancel,
} from "./utils.ts";
import { BasicLinks, ConfirmDialog } from "./components.tsx";

interface Player {
  name: string;
  scores: number[];
}

interface GolfState {
  title: string;
  numberOfHoles: number;
  pars: number[];
  currentHole: number;
  players: Player[];
}

interface RemotePlayer {
  name: string;
  scores?: number[];
}

interface RemoteGolfData {
  title?: string;
  numberOfHoles?: number;
  pars?: number[];
  currentHole?: number;
  players?: RemotePlayer[];
}

const DEFAULT_PARS_18 = [4, 4, 3, 4, 5, 4, 3, 4, 4, 4, 4, 3, 5, 4, 4, 3, 4, 5];
const DEFAULT_PARS_9 = [4, 4, 3, 4, 5, 4, 3, 4, 4];
const MAX_HOLES = DEFAULT_PARS_18.length;
const MAX_SCORE = 9;

function ensureLength(arr: number[], len: number, fill: number): number[] {
  const out = [...arr];
  while (out.length < len) out.push(fill);
  return out;
}

function totalRelativeToPar(
  players: Player[],
  pars: number[],
  numberOfHoles: number,
  playerIndex: number,
): number {
  let total = 0;
  for (let holeIndex = 0; holeIndex < numberOfHoles; holeIndex++) {
    const score = players[playerIndex].scores[holeIndex];
    if (score >= 0) total += score - pars[holeIndex];
  }
  return total;
}

function totalStrokes(players: Player[], numberOfHoles: number, playerIndex: number): number {
  let total = 0;
  for (let holeIndex = 0; holeIndex < numberOfHoles; holeIndex++) {
    const score = players[playerIndex].scores[holeIndex];
    if (score >= 0) total += score;
  }
  return total;
}

function holesPlayed(players: Player[], numberOfHoles: number, playerIndex: number): number {
  return players[playerIndex].scores.slice(0, numberOfHoles).filter((score) => score >= 0).length;
}

function fmtRelPar(val: number): string {
  if (val === 0) return "E";
  return val > 0 ? `+${val}` : `${val}`;
}

function scoreClass(strokes: number, par: number): string {
  if (strokes < 0) return "empty-cell";
  const diff = strokes - par;
  if (diff <= -2) return "eagle";
  if (diff === -1) return "birdie";
  if (diff === 0) return "par-cell";
  if (diff === 1) return "bogey";
  if (diff === 2) return "double-bogey";
  return "triple-bogey";
}

function totalClass(val: number): string {
  if (val < 0) return "score-under";
  if (val > 0) return "score-over";
  return "score-even";
}

function scoreOptionColor(score: number, par: number): string {
  if (score < 0) return "";
  const diff = score - par;
  if (diff <= -2) return "#60a5fa";
  if (diff === -1) return "#4ade80";
  if (diff === 0) return "";
  if (diff === 1) return "#f74e4e";
  if (diff === 2) return "#c084fc";
  return "#8a5a2b";
}

function App() {
  const [state, setState] = createStore<GolfState>({
    title: "",
    numberOfHoles: 18,
    pars: [...DEFAULT_PARS_18],
    currentHole: 0,
    players: [
      { name: "Player 1", scores: Array(MAX_HOLES).fill(-1) as number[] },
      { name: "Player 2", scores: Array(MAX_HOLES).fill(-1) as number[] },
    ],
  });

  const [status, setStatus] = createSignal<string>(connectionStatus.connecting);
  const [confirmMessage, setConfirmMessage] = createSignal("");
  const [confirmOpen, setConfirmOpen] = createSignal(false);

  class GolfConnection extends WebSocketConnection {
    onStatusChanged(newStatus: string): void {
      setStatus(newStatus);
    }

    onConnected(): void {
      this.sendGetGolfScoreboard();
    }

    handleResponse(_id: number, result: { ok: boolean }, data: unknown): void {
      if (!result.ok) return;
      if (!data) return;
      const d = data as { getGolfScoreboard?: { data: RemoteGolfData } };
      if (d.getGolfScoreboard) {
        applyRemoteState(d.getGolfScoreboard.data);
      }
    }

    handleEvent(data: unknown): void {
      const d = data as { golfScoreboard?: { data: RemoteGolfData } };
      if (d.golfScoreboard) {
        applyRemoteState(d.golfScoreboard.data);
      }
    }
  }

  const connection = new GolfConnection();

  function applyRemoteState(data: RemoteGolfData | null | undefined): void {
    if (!data) return;
    setState((prevState) => ({
      ...prevState,
      title: data.title ?? prevState.title,
      numberOfHoles: data.numberOfHoles ?? prevState.numberOfHoles,
      pars: Array.isArray(data.pars) && data.pars.length >= 18 ? data.pars : prevState.pars,
      currentHole: data.currentHole ?? prevState.currentHole,
      players:
        Array.isArray(data.players) && data.players.length > 0
          ? data.players.map((player) => ({
              name: player.name,
              scores: ensureLength(player.scores ?? [], MAX_HOLES, -1),
            }))
          : prevState.players,
    }));
  }

  function sendUpdate() {
    connection.updateGolfScoreboard({
      title: state.title,
      numberOfHoles: state.numberOfHoles,
      pars: state.pars,
      currentHole: state.currentHole,
      players: state.players.map((player) => ({ name: player.name, scores: player.scores })),
    });
  }

  function selectHole(holeIndex: number): void {
    setState("currentHole", holeIndex);
    sendUpdate();
  }

  function setPlayerName(playerIndex: number, name: string): void {
    setState("players", playerIndex, "name", name || `Player ${playerIndex + 1}`);
    sendUpdate();
  }

  function setScore(playerIndex: number, hole: number, score: number): void {
    setState("players", playerIndex, "scores", hole, score);
    sendUpdate();
  }

  function addPlayer(): void {
    if (state.players.length >= 4) return;
    const playerNumber = state.players.length + 1;
    setState("players", (players) => [
      ...players,
      { name: `Player ${playerNumber}`, scores: Array(MAX_HOLES).fill(-1) as number[] },
    ]);
    sendUpdate();
  }

  async function removePlayer(): Promise<void> {
    if (state.players.length <= 1) return;
    const ok = await showConfirm("Remove the last player?", setConfirmMessage, setConfirmOpen);
    if (!ok) return;
    setState("players", (players) => players.slice(0, -1));
    sendUpdate();
  }

  async function newRound(): Promise<void> {
    const ok = await showConfirm(
      "Start a new round? All scores will be cleared.",
      setConfirmMessage,
      setConfirmOpen,
    );
    if (!ok) return;
    setState("players", (players) =>
      players.map((player) => ({ ...player, scores: Array(MAX_HOLES).fill(-1) as number[] })),
    );
    setState("currentHole", 0);
    sendUpdate();
  }

  function changeNumberOfHoles(holeCount: number): void {
    const newPars = holeCount === 9 ? [...DEFAULT_PARS_9] : [...DEFAULT_PARS_18];
    const newHole = Math.min(state.currentHole, holeCount - 1);
    setState({ numberOfHoles: holeCount, pars: newPars, currentHole: newHole });
    sendUpdate();
  }

  function changeCurrentPar(par: number): void {
    if (isNaN(par)) return;
    setState("pars", state.currentHole, par);
    sendUpdate();
  }

  const leaderboard = () => {
    return state.players
      .map((player, playerIndex) => ({
        name: player.name,
        total: totalRelativeToPar(state.players, state.pars, state.numberOfHoles, playerIndex),
        thru: holesPlayed(state.players, state.numberOfHoles, playerIndex),
        index: playerIndex,
      }))
      .sort((entryA, entryB) => entryA.total - entryB.total);
  };

  function ConnectionStatus() {
    return (
      <div class="pb-1 text-center text-sm">
        <Switch fallback={<span class="text-red-500">Unknown server status</span>}>
          <Match when={status() === connectionStatus.connecting}>
            <span class="text-yellow-400">Connecting to server</span>
          </Match>
          <Match when={status() === connectionStatus.connected}>
            <span class="text-green-500">Connected to server</span>
          </Match>
        </Switch>
      </div>
    );
  }

  function Event() {
    return (
      <div class="card">
        <div class="grid grid-cols-2 gap-2">
          <input
            type="text"
            placeholder="Event name"
            value={state.title}
            class="bg-zinc-800 border border-zinc-700 rounded px-2 py-1 text-sm"
            onBlur={(event) => {
              setState("title", event.target.value);
              sendUpdate();
            }}
          />
          <select
            value={String(state.numberOfHoles)}
            class="bg-zinc-800 border border-zinc-700 rounded px-2 py-1 text-sm"
            onChange={(event) => changeNumberOfHoles(parseInt(event.target.value))}
          >
            <option value="9">9 Holes</option>
            <option value="18">18 Holes</option>
          </select>
        </div>
      </div>
    );
  }

  function Players() {
    return (
      <div class="card">
        <div class="flex items-center justify-between mb-2">
          <div class="text-xs text-zinc-500"></div>
          <div class="flex gap-1">
            <button
              class="btn-xs border-zinc-700 text-zinc-400"
              disabled={state.players.length <= 1}
              onClick={removePlayer}
            >
              Remove player
            </button>
            <button
              class="btn-xs border-zinc-600 text-zinc-300"
              disabled={state.players.length >= 4}
              onClick={addPlayer}
            >
              Add player
            </button>
          </div>
        </div>
        <div class="space-y-1">
          <For each={state.players}>
            {(player, playerIndex) => (
              <div class="flex items-center gap-2">
                <span class="text-xs text-zinc-500 w-16 shrink-0">Player {playerIndex() + 1}</span>
                <input
                  type="text"
                  class="flex-1 bg-zinc-800 border border-zinc-700 rounded px-2 py-1 text-sm"
                  placeholder="Name"
                  value={player.name}
                  onBlur={(event) => setPlayerName(playerIndex(), event.target.value)}
                />
              </div>
            )}
          </For>
        </div>
      </div>
    );
  }

  function Holes() {
    return (
      <div class="card">
        <div class="space-y-2">
          <div class="flex gap-2 items-center flex-wrap">
            <div class="flex flex-wrap gap-1 flex-1">
              <For each={Array.from({ length: state.numberOfHoles }, (_, holeIndex) => holeIndex)}>
                {(holeIndex) => {
                  const allScored = () =>
                    state.players.every((player) => player.scores[holeIndex] >= 0);
                  const anyScored = () =>
                    state.players.some((player) => player.scores[holeIndex] >= 0);
                  const isActive = () => holeIndex === state.currentHole;
                  const extraClass = () => {
                    if (isActive()) return "";
                    if (allScored()) return " complete";
                    if (anyScored()) return " played";
                    return "";
                  };
                  return (
                    <button
                      class={`hole-btn${isActive() ? " active" : ""}${extraClass()}`}
                      onClick={() => selectHole(holeIndex)}
                    >
                      {holeIndex + 1}
                    </button>
                  );
                }}
              </For>
            </div>
            <div class="flex items-center gap-1 shrink-0">
              <span class="text-xs text-zinc-500">Par</span>
              <select
                value={String(state.pars[state.currentHole] ?? 4)}
                class="bg-zinc-800 border border-zinc-700 rounded px-2 py-1 text-sm"
                onChange={(event) => changeCurrentPar(parseInt(event.target.value))}
              >
                <For each={[9, 8, 7, 6, 5, 4, 3, 2, 1]}>
                  {(parValue) => <option value={String(parValue)}>{parValue}</option>}
                </For>
              </select>
            </div>
          </div>
          <For each={state.players}>
            {(player, playerIndex) => {
              const par = () => state.pars[state.currentHole] ?? 4;
              const val = () => player.scores[state.currentHole];
              const selectColor = () => scoreOptionColor(val(), par());
              return (
                <div class="flex items-center gap-2">
                  <span class="text-sm flex-1 truncate">{player.name}</span>
                  <select
                    class="score-select"
                    style={{ color: val() >= 0 ? selectColor() : "" }}
                    value={String(val())}
                    onChange={(event) => {
                      const score = parseInt(event.target.value);
                      event.target.style.color = score >= 0 ? scoreOptionColor(score, par()) : "";
                      setScore(playerIndex(), state.currentHole, score);
                    }}
                  >
                    <For
                      each={Array.from(
                        { length: MAX_SCORE },
                        (_, scoreIndex) => MAX_SCORE - scoreIndex,
                      )}
                    >
                      {(score) => {
                        const color = scoreOptionColor(score, par());
                        const rel = fmtRelPar(score - par());
                        return (
                          <option value={String(score)} style={{ color }}>
                            {score} ({rel})
                          </option>
                        );
                      }}
                    </For>
                    <option value="-1">-</option>
                  </select>
                </div>
              );
            }}
          </For>
        </div>
      </div>
    );
  }

  function Leaderboard() {
    return (
      <div class="card">
        <table class="w-full text-sm">
          <thead>
            <tr class="text-xs text-zinc-500">
              <th class="text-left pb-1">Player</th>
              <th class="text-right pb-1">Score</th>
              <th class="text-right pb-1">Thru</th>
            </tr>
          </thead>
          <tbody>
            <For each={leaderboard()}>
              {({ name, total, thru }) => {
                const thruText = thru === 0 ? "–" : thru < state.numberOfHoles ? String(thru) : "F";
                return (
                  <tr>
                    <td class="py-1 truncate max-w-xs">{name}</td>
                    <td class={`text-right font-bold text-base ${totalClass(total)}`}>
                      {fmtRelPar(total)}
                    </td>
                    <td class="text-right text-zinc-500 text-xs">{thruText}</td>
                  </tr>
                );
              }}
            </For>
          </tbody>
        </table>
      </div>
    );
  }

  function FullScorecard() {
    return (
      <div class="card">
        <div class="overflow-x-auto">
          <table class="scorecard-table text-xs">
            <thead>
              <tr>
                <th class="player-name-cell">Player</th>
                <For
                  each={Array.from({ length: state.numberOfHoles }, (_, holeIndex) => holeIndex)}
                >
                  {(holeIndex) => <th>{holeIndex + 1}</th>}
                </For>
                <th class="total-cell">Total</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td class="player-name-cell text-zinc-500">Par</td>
                <For each={state.pars.slice(0, state.numberOfHoles)}>
                  {(par) => <td class="text-zinc-500">{par}</td>}
                </For>
                <td class="total-cell text-zinc-500">
                  {state.pars.slice(0, state.numberOfHoles).reduce((sum, par) => sum + par, 0)}
                </td>
              </tr>
              <For each={state.players}>
                {(player, playerIndex) => {
                  const total = () =>
                    totalRelativeToPar(
                      state.players,
                      state.pars,
                      state.numberOfHoles,
                      playerIndex(),
                    );
                  const strokes = () =>
                    totalStrokes(state.players, state.numberOfHoles, playerIndex());
                  const totalText = () => {
                    const strokesTotal = strokes();
                    const totalScore = total();
                    return strokesTotal > 0
                      ? `${strokesTotal} (${fmtRelPar(totalScore)})`
                      : fmtRelPar(totalScore);
                  };
                  return (
                    <tr>
                      <td class="player-name-cell">{player.name}</td>
                      <For
                        each={Array.from(
                          { length: state.numberOfHoles },
                          (_, holeIndex) => holeIndex,
                        )}
                      >
                        {(holeIndex) => {
                          const score = player.scores[holeIndex];
                          const cls = scoreClass(score, state.pars[holeIndex]);
                          return <td class={cls}>{score >= 0 ? score : ""}</td>;
                        }}
                      </For>
                      <td class={`total-cell ${totalClass(total())}`}>{totalText()}</td>
                    </tr>
                  );
                }}
              </For>
            </tbody>
          </table>
        </div>
      </div>
    );
  }

  function Buttons() {
    return (
      <div class="card">
        <button class="new-round-btn border-zinc-700 text-red-400" onClick={newRound}>
          New Round
        </button>
      </div>
    );
  }

  return (
    <div class="max-w-3xl mx-auto space-y-2">
      <h1 class="text-2xl font-bold text-center">Moblin Golf Scoreboard</h1>
      <BasicLinks />
      <ConnectionStatus />
      <Event />
      <Players />
      <Holes />
      <Leaderboard />
      <FullScorecard />
      <Buttons />
      <ConfirmDialog
        open={confirmOpen}
        message={confirmMessage}
        onOk={confirmOk}
        onCancel={confirmCancel}
        okTextClass="text-zinc-300"
      />
    </div>
  );
}

render(() => <App />, document.getElementById("app")!);
