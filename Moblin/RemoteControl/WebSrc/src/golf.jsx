import { createSignal, For, Show, onMount } from "solid-js";
import { createStore } from "solid-js/store";
import { render } from "solid-js/web";
import { WebSocketConnection, showConfirm, confirmOk, confirmCancel } from "./utils.js";

const DEFAULT_PARS_18 = [4, 4, 3, 4, 5, 4, 3, 4, 4, 4, 4, 3, 5, 4, 4, 3, 4, 5];
const DEFAULT_PARS_9 = [4, 4, 3, 4, 5, 4, 3, 4, 4];
const MAX_HOLES = DEFAULT_PARS_18.length;
const MAX_SCORE = 9;

function ensureLength(arr, len, fill) {
  const out = [...arr];
  while (out.length < len) out.push(fill);
  return out;
}

function totalRelativeToPar(players, pars, numberOfHoles, playerIndex) {
  let total = 0;
  for (let h = 0; h < numberOfHoles; h++) {
    const s = players[playerIndex].scores[h];
    if (s >= 0) total += s - pars[h];
  }
  return total;
}

function totalStrokes(players, numberOfHoles, playerIndex) {
  let total = 0;
  for (let h = 0; h < numberOfHoles; h++) {
    const s = players[playerIndex].scores[h];
    if (s >= 0) total += s;
  }
  return total;
}

function holesPlayed(players, numberOfHoles, playerIndex) {
  return players[playerIndex].scores.slice(0, numberOfHoles).filter((s) => s >= 0).length;
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

function App() {
  const [state, setState] = createStore({
    title: "",
    numberOfHoles: 18,
    pars: [...DEFAULT_PARS_18],
    currentHole: 0,
    players: [
      { name: "Player 1", scores: Array(MAX_HOLES).fill(-1) },
      { name: "Player 2", scores: Array(MAX_HOLES).fill(-1) },
    ],
  });

  const [confirmMessage, setConfirmMessage] = createSignal("");
  const [confirmOpen, setConfirmOpen] = createSignal(false);

  class GolfConnection extends WebSocketConnection {
    onConnected() {
      this.sendGetGolfScoreboard();
    }

    handleResponse(_id, result, data) {
      if (!result.ok) return;
      if (!data) return;
      if (data.getGolfScoreboard) {
        applyRemoteState(data.getGolfScoreboard.data);
      }
    }

    handleEvent(data) {
      if (data.golfScoreboard) {
        applyRemoteState(data.golfScoreboard.data);
      }
    }
  }

  const connection = new GolfConnection();

  function applyRemoteState(data) {
    if (!data) return;
    setState((s) => ({
      ...s,
      title: data.title ?? s.title,
      numberOfHoles: data.numberOfHoles ?? s.numberOfHoles,
      pars:
        Array.isArray(data.pars) && data.pars.length >= 18 ? data.pars : s.pars,
      currentHole: data.currentHole ?? s.currentHole,
      players:
        Array.isArray(data.players) && data.players.length > 0
          ? data.players.map((p) => ({
              name: p.name,
              scores: ensureLength(p.scores ?? [], MAX_HOLES, -1),
            }))
          : s.players,
    }));
  }

  function sendUpdate() {
    connection.updateGolfScoreboard({
      title: state.title,
      numberOfHoles: state.numberOfHoles,
      pars: state.pars,
      currentHole: state.currentHole,
      players: state.players.map((p) => ({ name: p.name, scores: p.scores })),
    });
  }

  function selectHole(h) {
    setState("currentHole", h);
    sendUpdate();
  }

  function setPlayerName(i, name) {
    setState("players", i, "name", name || `Player ${i + 1}`);
    sendUpdate();
  }

  function setScore(playerIndex, hole, score) {
    setState("players", playerIndex, "scores", hole, score);
    sendUpdate();
  }

  function addPlayer() {
    if (state.players.length >= 4) return;
    const n = state.players.length + 1;
    setState("players", (ps) => [
      ...ps,
      { name: `Player ${n}`, scores: Array(MAX_HOLES).fill(-1) },
    ]);
    sendUpdate();
  }

  async function removePlayer() {
    if (state.players.length <= 1) return;
    const ok = await showConfirm(
      "Remove the last player?",
      setConfirmMessage,
      setConfirmOpen,
    );
    if (!ok) return;
    setState("players", (ps) => ps.slice(0, -1));
    sendUpdate();
  }

  async function newRound() {
    const ok = await showConfirm(
      "Start a new round? All scores will be cleared.",
      setConfirmMessage,
      setConfirmOpen,
    );
    if (!ok) return;
    setState("players", (ps) =>
      ps.map((p) => ({ ...p, scores: Array(MAX_HOLES).fill(-1) })),
    );
    setState("currentHole", 0);
    sendUpdate();
  }

  function changeNumberOfHoles(n) {
    const newPars = n === 9 ? [...DEFAULT_PARS_9] : [...DEFAULT_PARS_18];
    const newHole = Math.min(state.currentHole, n - 1);
    setState({ numberOfHoles: n, pars: newPars, currentHole: newHole });
    sendUpdate();
  }

  function changeCurrentPar(p) {
    if (isNaN(p)) return;
    setState("pars", state.currentHole, p);
    sendUpdate();
  }

  const leaderboard = () => {
    return state.players
      .map((p, i) => ({
        name: p.name,
        total: totalRelativeToPar(state.players, state.pars, state.numberOfHoles, i),
        thru: holesPlayed(state.players, state.numberOfHoles, i),
        index: i,
      }))
      .sort((a, b) => a.total - b.total);
  };

  return (
    <div class="max-w-3xl mx-auto space-y-2">
      <h1 class="text-2xl font-bold text-center">Moblin Golf Scoreboard</h1>

      <div class="text-center space-x-4">
        <a href="./" class="text-indigo-400 hover:text-indigo-300 text-sm">
          Remote Control
        </a>
        <a
          href="https://github.com/eerimoq/moblin"
          target="_blank"
          class="text-indigo-400 hover:text-indigo-300 text-sm"
        >
          Github
        </a>
      </div>

      {/* Event card */}
      <div class="card">
        <div class="text-xs text-zinc-500 mb-2">Event</div>
        <div class="grid grid-cols-2 gap-2">
          <input
            type="text"
            placeholder="Event name"
            value={state.title}
            class="bg-zinc-800 border border-zinc-700 rounded px-2 py-1 text-sm"
            onBlur={(e) => {
              setState("title", e.target.value);
              sendUpdate();
            }}
          />
          <select
            value={String(state.numberOfHoles)}
            class="bg-zinc-800 border border-zinc-700 rounded px-2 py-1 text-sm"
            onChange={(e) => changeNumberOfHoles(parseInt(e.target.value))}
          >
            <option value="9">9 Holes</option>
            <option value="18">18 Holes</option>
          </select>
        </div>
      </div>

      {/* Players card */}
      <div class="card">
        <div class="flex items-center justify-between mb-2">
          <div class="text-xs text-zinc-500">Players</div>
          <div class="flex gap-1">
            <button
              class="btn-xs border-zinc-700 text-zinc-400"
              disabled={state.players.length <= 1}
              onClick={removePlayer}
            >
              − Player
            </button>
            <button
              class="btn-xs border-zinc-600 text-zinc-300"
              disabled={state.players.length >= 4}
              onClick={addPlayer}
            >
              + Player
            </button>
          </div>
        </div>
        <div class="space-y-1">
          <For each={state.players}>
            {(player, i) => (
              <div class="flex items-center gap-2">
                <span class="text-xs text-zinc-500 w-16 shrink-0">
                  Player {i() + 1}
                </span>
                <input
                  type="text"
                  class="flex-1 bg-zinc-800 border border-zinc-700 rounded px-2 py-1 text-sm"
                  placeholder="Name"
                  value={player.name}
                  onBlur={(e) => setPlayerName(i(), e.target.value)}
                />
              </div>
            )}
          </For>
        </div>
      </div>

      {/* Current Hole card */}
      <div class="card">
        <div class="text-xs text-zinc-500 mb-2">Current Hole</div>
        <div class="flex gap-2 items-center flex-wrap">
          <div class="flex flex-wrap gap-1 flex-1">
            <For each={Array.from({ length: state.numberOfHoles }, (_, h) => h)}>
              {(h) => {
                const allScored = () =>
                  state.players.every((p) => p.scores[h] >= 0);
                const anyScored = () =>
                  state.players.some((p) => p.scores[h] >= 0);
                const isActive = () => h === state.currentHole;
                const extraClass = () => {
                  if (isActive()) return "";
                  if (allScored()) return " complete";
                  if (anyScored()) return " played";
                  return "";
                };
                return (
                  <button
                    class={`hole-btn${isActive() ? " active" : ""}${extraClass()}`}
                    onClick={() => selectHole(h)}
                  >
                    {h + 1}
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
              onChange={(e) => changeCurrentPar(parseInt(e.target.value))}
            >
              <For each={[9, 8, 7, 6, 5, 4, 3, 2, 1]}>
                {(v) => <option value={String(v)}>{v}</option>}
              </For>
            </select>
          </div>
        </div>
      </div>

      {/* Score inputs card */}
      <div class="card">
        <div class="text-xs text-zinc-500 mb-2">
          Scores — Hole {state.currentHole + 1}
        </div>
        <div class="space-y-2">
          <For each={state.players}>
            {(player, i) => {
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
                    onChange={(e) => {
                      const score = parseInt(e.target.value);
                      e.target.style.color =
                        score >= 0 ? scoreOptionColor(score, par()) : "";
                      setScore(i(), state.currentHole, score);
                    }}
                  >
                    <For
                      each={Array.from({ length: MAX_SCORE }, (_, k) => MAX_SCORE - k)}
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

      {/* Leaderboard card */}
      <div class="card">
        <div class="text-xs text-zinc-500 mb-2">Leaderboard</div>
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
                const thruText =
                  thru === 0
                    ? "–"
                    : thru < state.numberOfHoles
                      ? String(thru)
                      : "F";
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

      {/* Full Scorecard card */}
      <div class="card">
        <details>
          <summary class="text-sm text-zinc-400 cursor-pointer py-1">
            Full Scorecard
          </summary>
          <div class="overflow-x-auto mt-2">
            <table class="scorecard-table text-xs">
              <thead>
                <tr>
                  <th class="player-name-cell">Player</th>
                  <For
                    each={Array.from({ length: state.numberOfHoles }, (_, h) => h)}
                  >
                    {(h) => <th>{h + 1}</th>}
                  </For>
                  <th class="total-cell">Total</th>
                </tr>
              </thead>
              <tbody>
                <tr>
                  <td class="player-name-cell text-zinc-500">Par</td>
                  <For each={state.pars.slice(0, state.numberOfHoles)}>
                    {(p) => <td class="text-zinc-500">{p}</td>}
                  </For>
                  <td class="total-cell text-zinc-500">
                    {state.pars.slice(0, state.numberOfHoles).reduce((a, b) => a + b, 0)}
                  </td>
                </tr>
                <For each={state.players}>
                  {(player, i) => {
                    const total = () =>
                      totalRelativeToPar(
                        state.players,
                        state.pars,
                        state.numberOfHoles,
                        i(),
                      );
                    const strokes = () =>
                      totalStrokes(state.players, state.numberOfHoles, i());
                    const totalText = () => {
                      const s = strokes();
                      const t = total();
                      return s > 0 ? `${s} (${fmtRelPar(t)})` : fmtRelPar(t);
                    };
                    return (
                      <tr>
                        <td class="player-name-cell">{player.name}</td>
                        <For
                          each={Array.from(
                            { length: state.numberOfHoles },
                            (_, h) => h,
                          )}
                        >
                          {(h) => {
                            const s = player.scores[h];
                            const cls = scoreClass(s, state.pars[h]);
                            return <td class={cls}>{s >= 0 ? s : ""}</td>;
                          }}
                        </For>
                        <td class={`total-cell ${totalClass(total())}`}>
                          {totalText()}
                        </td>
                      </tr>
                    );
                  }}
                </For>
              </tbody>
            </table>
          </div>
        </details>
      </div>

      {/* New Round card */}
      <div class="card">
        <button
          class="new-round-btn border-zinc-700 text-red-400"
          onClick={newRound}
        >
          New Round
        </button>
      </div>

      {/* Confirm dialog */}
      <Show when={confirmOpen()}>
        <dialog
          open
          class="backdrop:bg-black/60 rounded-xl p-0"
          style={{ position: "fixed", top: "50%", left: "50%", transform: "translate(-50%, -50%)", margin: 0 }}
        >
          <form method="dialog" class="bg-zinc-900 text-zinc-100">
            <div class="p-2">
              <p class="text-zinc-300">{confirmMessage()}</p>
            </div>
            <div class="bg-zinc-800/60 px-4 py-3 sm:px-5 flex items-center justify-end gap-2">
              <button
                type="button"
                class="px-3 py-1.5 rounded-md border border-zinc-700 text-zinc-300 hover:bg-zinc-800 cursor-pointer"
                onClick={confirmOk}
              >
                OK
              </button>
              <button
                type="button"
                class="px-3 py-1.5 rounded-md border border-zinc-700 text-zinc-300 hover:bg-zinc-800 cursor-pointer"
                onClick={confirmCancel}
              >
                Cancel
              </button>
            </div>
          </form>
        </dialog>
      </Show>
    </div>
  );
}

render(() => <App />, document.getElementById("app"));
