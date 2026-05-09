<svelte:head>
  <title>Moblin Golf Scoreboard</title>
  <link rel="stylesheet" href="css/app.css" />
  <link rel="stylesheet" href="css/common.css" />
  <link rel="stylesheet" href="css/golf.css" />
</svelte:head>

<script>
  import { WebSocketConnection } from "./lib/websocket.js";

  const DEFAULT_PARS_18 = [4, 4, 3, 4, 5, 4, 3, 4, 4, 4, 4, 3, 5, 4, 4, 3, 4, 5];
  const DEFAULT_PARS_9 = [4, 4, 3, 4, 5, 4, 3, 4, 4];
  const MAX_HOLES = DEFAULT_PARS_18.length;
  const MAX_SCORE = 9;

  let title = $state("");
  let numberOfHoles = $state(18);
  let pars = $state([...DEFAULT_PARS_18]);
  let currentHole = $state(0);
  let players = $state([
    { name: "Player 1", scores: Array(MAX_HOLES).fill(-1) },
    { name: "Player 2", scores: Array(MAX_HOLES).fill(-1) },
  ]);

  let confirmMessage = $state("");
  let confirmResolve = $state(null);
  let connStatus = $state("connecting");

  function ensureLength(arr, len, fill) {
    const out = [...arr];
    while (out.length < len) out.push(fill);
    return out;
  }

  function totalRelativeToPar(playerIndex) {
    let total = 0;
    for (let h = 0; h < numberOfHoles; h++) {
      const s = players[playerIndex].scores[h];
      if (s >= 0) total += s - pars[h];
    }
    return total;
  }

  function totalStrokes(playerIndex) {
    let total = 0;
    for (let h = 0; h < numberOfHoles; h++) {
      const s = players[playerIndex].scores[h];
      if (s >= 0) total += s;
    }
    return total;
  }

  function holesPlayed(playerIndex) {
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

  // Leaderboard derived
  let leaderboard = $derived.by(() =>
    players
      .map((p, i) => ({ name: p.name, total: totalRelativeToPar(i), thru: holesPlayed(i) }))
      .sort((a, b) => a.total - b.total),
  );

  // Scorecard hole range
  let holeRange = $derived(Array.from({ length: numberOfHoles }, (_, i) => i));

  // Course par
  let coursePar = $derived(pars.slice(0, numberOfHoles).reduce((a, b) => a + b, 0));

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

  // --- WebSocket connection ---
  class Connection extends WebSocketConnection {
    onStatusChanged(s) {
      connStatus = s;
    }

    onConnected() {
      this.sendGetGolfScoreboard();
    }

    sendUpdateGolfScoreboard() {
      this.sendRequest({
        updateGolfScoreboard: {
          data: {
            title,
            numberOfHoles,
            pars,
            currentHole,
            players: players.map((p) => ({ name: p.name, scores: p.scores })),
          },
        },
      });
    }

    handleResponse(_id, result, data) {
      if (!result.ok) {
        console.log("Unsuccessful request: ", result);
        return;
      }
      if (!data) return;
      if (data.getGolfScoreboard) applyRemoteState(data.getGolfScoreboard.data);
    }

    handleEvent(data) {
      if (data.golfScoreboard) applyRemoteState(data.golfScoreboard.data);
    }
  }

  function applyRemoteState(data) {
    if (!data) return;
    if (data.title !== undefined) title = data.title;
    if (data.numberOfHoles !== undefined) numberOfHoles = data.numberOfHoles;
    if (Array.isArray(data.pars) && data.pars.length >= 18) pars = data.pars;
    if (data.currentHole !== undefined) currentHole = data.currentHole;
    if (Array.isArray(data.players) && data.players.length > 0) {
      players = data.players.map((p) => ({
        name: p.name,
        scores: ensureLength(p.scores ?? [], MAX_HOLES, -1),
      }));
    }
  }

  const connection = new Connection();

  function selectHole(h) {
    currentHole = h;
    connection.sendUpdateGolfScoreboard();
  }

  function setPlayerScore(playerIndex, score) {
    players = players.map((p, i) =>
      i === playerIndex
        ? { ...p, scores: p.scores.map((s, h) => (h === currentHole ? score : s)) }
        : p,
    );
    connection.sendUpdateGolfScoreboard();
  }

  function setPlayerName(playerIndex, name) {
    players = players.map((p, i) =>
      i === playerIndex ? { ...p, name: name || `Player ${playerIndex + 1}` } : p,
    );
    connection.sendUpdateGolfScoreboard();
  }

  function setNumberOfHoles(n) {
    numberOfHoles = n;
    pars = n === 9 ? [...DEFAULT_PARS_9] : [...DEFAULT_PARS_18];
    if (currentHole >= n) currentHole = n - 1;
    connection.sendUpdateGolfScoreboard();
  }

  function setCurrentPar(p) {
    if (isNaN(p)) return;
    pars = pars.map((v, i) => (i === currentHole ? p : v));
    connection.sendUpdateGolfScoreboard();
  }

  async function addPlayer() {
    if (players.length >= 4) return;
    const n = players.length + 1;
    players = [...players, { name: `Player ${n}`, scores: Array(MAX_HOLES).fill(-1) }];
    connection.sendUpdateGolfScoreboard();
  }

  async function removePlayer() {
    if (players.length <= 1) return;
    if (!(await showConfirm("Remove the last player?"))) return;
    players = players.slice(0, -1);
    connection.sendUpdateGolfScoreboard();
  }

  async function newRound() {
    if (!(await showConfirm("Start a new round? All scores will be cleared."))) return;
    players = players.map((p) => ({ ...p, scores: Array(MAX_HOLES).fill(-1) }));
    currentHole = 0;
    connection.sendUpdateGolfScoreboard();
  }
</script>

<div class="bg-zinc-950 text-zinc-100 font-sans p-2">
  <div class="max-w-3xl mx-auto space-y-2">
    <h1 class="text-2xl font-bold text-center golf-title">Moblin Golf Scoreboard</h1>

    <div class="text-center space-x-4">
      <a href="./" class="text-indigo-400 hover:text-indigo-300 text-sm">Remote Control</a>
      <a
        href="https://github.com/eerimoq/moblin"
        target="_blank"
        class="text-indigo-400 hover:text-indigo-300 text-sm"
      >
        Github
      </a>
    </div>

    <!-- Event -->
    <div class="card">
      <div class="text-xs text-zinc-500 mb-2">Event</div>
      <div class="grid grid-cols-2 gap-2">
        <input
          type="text"
          id="title"
          placeholder="Event name"
          value={title}
          class="bg-zinc-800 border border-zinc-700 rounded px-2 py-1 text-sm"
          onblur={(e) => {
            title = e.target.value || "";
            connection.sendUpdateGolfScoreboard();
          }}
        />
        <select
          class="bg-zinc-800 border border-zinc-700 rounded px-2 py-1 text-sm"
          value={String(numberOfHoles)}
          onchange={(e) => setNumberOfHoles(parseInt(e.target.value))}
        >
          <option value="9">9 Holes</option>
          <option value="18">18 Holes</option>
        </select>
      </div>
    </div>

    <!-- Players -->
    <div class="card">
      <div class="flex items-center justify-between mb-2">
        <div class="text-xs text-zinc-500">Players</div>
        <div class="flex gap-1">
          <button
            class="btn-xs border-zinc-700 text-zinc-400"
            disabled={players.length <= 1}
            onclick={removePlayer}
          >
            − Player
          </button>
          <button
            class="btn-xs border-zinc-600 text-zinc-300"
            disabled={players.length >= 4}
            onclick={addPlayer}
          >
            + Player
          </button>
        </div>
      </div>
      <div class="space-y-1">
        {#each players as player, i (i)}
          <div class="flex items-center gap-2">
            <span class="text-xs text-zinc-500 w-16 shrink-0">Player {i + 1}</span>
            <input
              type="text"
              class="flex-1 bg-zinc-800 border border-zinc-700 rounded px-2 py-1 text-sm"
              placeholder="Name"
              value={player.name}
              onblur={(e) => setPlayerName(i, e.target.value)}
            />
          </div>
        {/each}
      </div>
    </div>

    <!-- Current Hole -->
    <div class="card">
      <div class="text-xs text-zinc-500 mb-2">Current Hole</div>
      <div class="flex gap-2 items-center flex-wrap">
        <div class="flex flex-wrap gap-1 flex-1">
          {#each holeRange as h}
            {@const allScored = players.every((p) => p.scores[h] >= 0)}
            {@const anyScored = players.some((p) => p.scores[h] >= 0)}
            {@const isActive = h === currentHole}
            <button
              class="hole-btn {isActive
                ? 'active'
                : allScored
                  ? 'complete'
                  : anyScored
                    ? 'played'
                    : ''}"
              onclick={() => selectHole(h)}
            >
              {h + 1}
            </button>
          {/each}
        </div>
        <div class="flex items-center gap-1 shrink-0">
          <span class="text-xs text-zinc-500">Par</span>
          <select
            class="bg-zinc-800 border border-zinc-700 rounded px-2 py-1 text-sm"
            value={String(pars[currentHole] ?? 4)}
            onchange={(e) => setCurrentPar(parseInt(e.target.value))}
          >
            {#each [9, 8, 7, 6, 5, 4, 3, 2, 1] as v}
              <option value={String(v)}>{v}</option>
            {/each}
          </select>
        </div>
      </div>
    </div>

    <!-- Score Entry -->
    <div class="card">
      <div class="text-xs text-zinc-500 mb-2">
        Scores — Hole {currentHole + 1}
      </div>
      <div class="space-y-2">
        {#each players as player, pi (pi)}
          {@const par = pars[currentHole] ?? 4}
          {@const val = player.scores[currentHole]}
          {@const hasScore = val >= 0}
          {@const selColor = hasScore ? scoreOptionColor(val, par) : ""}
          <div class="flex items-center gap-2">
            <span class="text-sm flex-1 truncate">{player.name}</span>
            <select
              class="score-select"
              style={selColor ? `color:${selColor}` : ""}
              value={String(val)}
              onchange={(e) => {
                const score = parseInt(e.target.value);
                setPlayerScore(pi, score);
                e.target.style.color = scoreOptionColor(score, par);
              }}
            >
              {#each Array.from({ length: MAX_SCORE }, (_, k) => MAX_SCORE - k) as score}
                {@const color = scoreOptionColor(score, par)}
                {@const rel = fmtRelPar(score - par)}
                <option value={String(score)} style={color ? `color:${color}` : ""}
                  >{score} ({rel})</option
                >
              {/each}
              <option value="-1">-</option>
            </select>
          </div>
        {/each}
      </div>
    </div>

    <!-- Leaderboard -->
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
          {#each leaderboard as row}
            {@const thruText =
              row.thru === 0 ? "–" : row.thru < numberOfHoles ? String(row.thru) : "F"}
            <tr>
              <td class="py-1 truncate max-w-xs">{row.name}</td>
              <td class="text-right font-bold text-base {totalClass(row.total)}"
                >{fmtRelPar(row.total)}</td
              >
              <td class="text-right text-zinc-500 text-xs">{thruText}</td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>

    <!-- Full Scorecard -->
    <div class="card">
      <details>
        <summary class="text-sm text-zinc-400 cursor-pointer py-1">Full Scorecard</summary>
        <div class="overflow-x-auto mt-2">
          <table class="scorecard-table text-xs">
            <thead>
              <tr>
                <th class="player-name-cell">Player</th>
                {#each holeRange as h}
                  <th>{h + 1}</th>
                {/each}
                <th class="total-cell">Total</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td class="player-name-cell text-zinc-500">Par</td>
                {#each holeRange as h}
                  <td class="text-zinc-500">{pars[h]}</td>
                {/each}
                <td class="total-cell text-zinc-500">{coursePar}</td>
              </tr>
              {#each players as player, pi}
                {@const total = totalRelativeToPar(pi)}
                {@const strokes = totalStrokes(pi)}
                {@const totalText = strokes > 0 ? `${strokes} (${fmtRelPar(total)})` : fmtRelPar(total)}
                <tr>
                  <td class="player-name-cell">{player.name}</td>
                  {#each holeRange as h}
                    {@const s = player.scores[h]}
                    <td class={scoreClass(s, pars[h])}>{s >= 0 ? s : ""}</td>
                  {/each}
                  <td class="total-cell {totalClass(total)}">{totalText}</td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>
      </details>
    </div>

    <!-- New Round -->
    <div class="card">
      <button class="new-round-btn border-zinc-700 text-red-400" onclick={newRound}>
        New Round
      </button>
    </div>
  </div>
</div>

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
