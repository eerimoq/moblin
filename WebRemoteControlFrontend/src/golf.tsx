import { createEffect, For, Match, on, Show, Switch } from "solid-js";
import { twMerge } from "tailwind-merge";
import type { PageProps } from "./app.tsx";
import {
  Button,
  Card,
  ColorButton,
  EmptyState,
  Icon,
  Label,
  Segmented,
  Switch as Toggle,
  TextField,
} from "./components.tsx";
import type { Remote } from "./remote.ts";
import { hexToRgbColor, RemoteControlGolfPlayer, rgbColorToHex } from "./utils.ts";

const defaultPars18 = [4, 4, 3, 4, 5, 4, 3, 4, 4, 4, 4, 3, 5, 4, 4, 3, 4, 5];
const defaultPars9 = [4, 4, 3, 4, 5, 4, 3, 4, 4];
const maximumHoles = defaultPars18.length;
const maximumPlayers = 4;
const holePars = [2, 3, 4, 5, 6, 7];
const defaultPlayerColors = ["#4f82e6", "#e5484d", "#f2c230", "#30a46c"];

type ScoreKind = "eagle" | "birdie" | "par" | "bogey" | "double" | "none";

const scoreStyles: Record<ScoreKind, { cell: string; text: string }> = {
  eagle: { cell: "bg-eagle-surface text-eagle-fg", text: "text-eagle-fg" },
  birdie: { cell: "bg-success-surface text-success-fg", text: "text-success-fg" },
  par: { cell: "text-fg-2", text: "text-fg" },
  bogey: { cell: "bg-danger-surface text-bogey-fg", text: "text-bogey-fg" },
  double: { cell: "bg-double-surface text-double-fg", text: "text-double-fg" },
  none: { cell: "", text: "text-faint" },
};

const legend: [string, string][] = [
  ["Eagle", "border-eagle-fg bg-eagle-surface"],
  ["Birdie", "border-success-fg bg-success-surface"],
  ["Bogey", "border-bogey-fg bg-danger-surface"],
  ["Double+", "border-double-fg bg-double-surface"],
];

function scoreKind(strokes: number, par: number): ScoreKind {
  if (strokes < 0) return "none";
  const difference = strokes - par;
  if (difference <= -2) return "eagle";
  if (difference === -1) return "birdie";
  if (difference === 0) return "par";
  if (difference === 1) return "bogey";
  return "double";
}

function scoreName(strokes: number, par: number): string {
  if (strokes < 0) return "NOT SCORED";
  const difference = strokes - par;
  if (strokes === 1) return "HOLE IN ONE";
  if (difference <= -3) return "ALBATROSS";
  if (difference === -2) return "EAGLE";
  if (difference === -1) return "BIRDIE";
  if (difference === 0) return "PAR";
  if (difference === 1) return "BOGEY";
  if (difference === 2) return "DOUBLE BOGEY";
  return `+${difference}`;
}

function formatRelativePar(value: number): string {
  if (value === 0) return "E";
  return value > 0 ? `+${value}` : `−${-value}`;
}

function relativeClass(value: number): string {
  if (value < 0) return "text-success-fg";
  if (value > 0) return "text-bogey-fg";
  return "text-fg";
}

function holes(count: number, start = 0): number[] {
  return Array.from({ length: count }, (_, index) => start + index);
}

function createGolf(remote: Remote, confirm: PageProps["confirm"]) {
  const state = remote.golf;
  const setState = remote.setGolf;

  function send(): void {
    remote.connection.updateGolfScoreboard({
      title: state.title,
      numberOfHoles: state.numberOfHoles,
      pars: state.pars,
      currentHole: state.currentHole,
      players: state.players.map((player) => ({
        name: player.name,
        scores: player.scores,
        color: player.color,
      })),
      playerColors: state.playerColors,
    });
  }

  function par(hole: number): number {
    return state.pars[hole] ?? 4;
  }

  function strokes(player: RemoteControlGolfPlayer): number {
    return holes(state.numberOfHoles).reduce(
      (sum, hole) => sum + Math.max(0, player.scores[hole] ?? -1),
      0,
    );
  }

  function relative(player: RemoteControlGolfPlayer): number {
    return holes(state.numberOfHoles).reduce((sum, hole) => {
      const score = player.scores[hole] ?? -1;
      return score >= 0 ? sum + score - par(hole) : sum;
    }, 0);
  }

  function scoredHoles(player: RemoteControlGolfPlayer): number {
    return holes(state.numberOfHoles).filter((hole) => (player.scores[hole] ?? -1) >= 0).length;
  }

  function holeComplete(hole: number): boolean {
    return (
      state.players.length > 0 && state.players.every((player) => (player.scores[hole] ?? -1) >= 0)
    );
  }

  function holeStarted(hole: number): boolean {
    return state.players.some((player) => (player.scores[hole] ?? -1) >= 0);
  }

  function completeHoles(): number {
    return holes(state.numberOfHoles).filter(holeComplete).length;
  }

  function selectHole(hole: number): void {
    setState("currentHole", hole);
    send();
  }

  function setPar(value: number): void {
    setState("pars", state.currentHole, value);
    send();
  }

  function setScore(playerIndex: number, score: number): void {
    setState("players", playerIndex, "scores", state.currentHole, score);
    send();
  }

  function adjustScore(playerIndex: number, delta: number): void {
    const current = state.players[playerIndex].scores[state.currentHole] ?? -1;
    const base = current >= 0 ? current : par(state.currentHole);
    setScore(playerIndex, Math.min(10, Math.max(1, base + delta)));
  }

  function setTitle(title: string): void {
    setState("title", title);
    send();
  }

  function setNumberOfHoles(count: number): void {
    setState({
      numberOfHoles: count,
      pars: count === 9 ? [...defaultPars9] : [...defaultPars18],
      currentHole: Math.min(state.currentHole, count - 1),
    });
    send();
  }

  function setPlayerColors(on: boolean): void {
    setState("playerColors", on);
    send();
  }

  function setPlayerName(playerIndex: number, name: string): void {
    setState("players", playerIndex, "name", name || `Player ${playerIndex + 1}`);
    send();
  }

  function setPlayerColor(playerIndex: number, hex: string): void {
    setState("players", playerIndex, "color", hexToRgbColor(hex));
    send();
  }

  function addPlayer(): void {
    if (state.players.length >= maximumPlayers) return;
    const index = state.players.length;
    setState("players", (players) => [
      ...players,
      {
        name: `Player ${index + 1}`,
        scores: Array(maximumHoles).fill(-1) as number[],
        color: hexToRgbColor(defaultPlayerColors[index]),
      },
    ]);
    send();
  }

  function removeLastPlayer(): void {
    const player = state.players[state.players.length - 1];
    if (player === undefined) return;
    const scored = scoredHoles(player);
    confirm({
      title: `Remove ${player.name}?`,
      message: `${player.name}${scored > 0 ? ` and their ${scored} scored ${scored === 1 ? "hole" : "holes"}` : ""} will be removed from the round. This can't be undone.`,
      confirmLabel: "Remove player",
      onConfirm: () => {
        setState("players", (players) => players.slice(0, -1));
        send();
      },
    });
  }

  function newRound(): void {
    const names = state.players.map((player) => player.name);
    const who =
      names.length > 1
        ? `${names.slice(0, -1).join(", ")} and ${names[names.length - 1]}`
        : (names[0] ?? "all players");
    confirm({
      title: "Start a new round?",
      message: `All scores for ${who} will be cleared and play restarts at hole 1. Players and pars are kept.`,
      confirmLabel: "Clear scores",
      onConfirm: () => {
        setState("players", (players) =>
          players.map((player) => ({
            ...player,
            scores: Array(maximumHoles).fill(-1) as number[],
          })),
        );
        setState("currentHole", 0);
        send();
      },
    });
  }

  return {
    state,
    par,
    strokes,
    relative,
    holeComplete,
    holeStarted,
    completeHoles,
    selectHole,
    setPar,
    adjustScore,
    setScore,
    setTitle,
    setNumberOfHoles,
    setPlayerColors,
    setPlayerName,
    setPlayerColor,
    addPlayer,
    removeLastPlayer,
    newRound,
  };
}

type Golf = ReturnType<typeof createGolf>;

interface GolfProps extends PageProps {
  golf: Golf;
  class?: string;
}

function PlayerDot(props: { golf: Golf; player: RemoteControlGolfPlayer; class?: string }) {
  return (
    <div
      class={twMerge(
        "size-2.5 shrink-0 rounded-full",
        !props.golf.state.playerColors && "bg-faint",
        props.class,
      )}
      style={
        props.golf.state.playerColors
          ? { "background-color": rgbColorToHex(props.player.color) }
          : undefined
      }
    />
  );
}

function HoleCard(props: GolfProps) {
  const golf = props.golf;
  const state = golf.state;
  const mobile = () => props.layout() === "mobile";
  let strip: HTMLDivElement | undefined;

  createEffect(
    on([() => state.currentHole, mobile], () => {
      const button = strip?.children[state.currentHole] as HTMLElement | undefined;
      button?.scrollIntoView({ inline: "center", block: "nearest" });
    }),
  );

  const progress = () => {
    const complete = golf.completeHoles();
    if (mobile()) return `${complete} complete`;
    return complete === 0 ? "no scores yet" : `${complete} of ${state.numberOfHoles} complete`;
  };

  const parSelector = (itemClass: string) => (
    <Segmented
      class="rounded-lg"
      itemClass={twMerge("rounded-md text-[13px]", itemClass)}
      options={holePars.map((value) => ({ value, label: String(value) }))}
      value={golf.par(state.currentHole)}
      onChange={golf.setPar}
    />
  );

  return (
    <Card class="gap-3 tablet:gap-3.5">
      <div class="flex items-center justify-between gap-4">
        <div class="flex items-center gap-4">
          <Label>
            {mobile() ? `Hole ${state.currentHole + 1} of ${state.numberOfHoles}` : "Hole"}
          </Label>
          <span class="text-[11px] text-faint">{progress()}</span>
        </div>
        <Show when={!mobile()}>
          <div class="flex items-center gap-2.5">
            <span class="text-[12px] text-muted">Par for hole {state.currentHole + 1}</span>
            {parSelector("h-7 w-[34px] flex-none")}
          </div>
        </Show>
      </div>
      <div
        ref={(element) => (strip = element)}
        class={twMerge(
          mobile() ? "flex gap-1 overflow-x-auto" : "grid gap-1.5",
          !mobile() && (props.layout() === "desktop" ? "grid-cols-18" : "grid-cols-9"),
        )}
        style={
          !mobile() && state.numberOfHoles === 9
            ? { "grid-template-columns": "repeat(9, minmax(0, 1fr))" }
            : undefined
        }
      >
        <For each={holes(state.numberOfHoles)}>
          {(hole) => {
            const current = () => hole === state.currentHole;
            return (
              <button
                type="button"
                class={twMerge(
                  "flex shrink-0 flex-col items-center justify-center gap-0.5 rounded-[9px]",
                  mobile() ? "h-11 w-[38px] rounded-lg text-[13px]" : "h-12 text-[14px]",
                  current()
                    ? "bg-accent font-semibold text-white"
                    : "border border-control-stroke bg-control",
                  !current() && (golf.holeStarted(hole) ? "text-fg" : "text-muted"),
                )}
                onClick={() => golf.selectHole(hole)}
              >
                {hole + 1}
                <Show when={current() && !mobile()}>
                  <span class="text-[9px] font-normal">PAR {golf.par(hole)}</span>
                </Show>
                <Show when={!current() && golf.holeStarted(hole)}>
                  <div
                    class={twMerge(
                      "size-1 rounded-full",
                      golf.holeComplete(hole) ? "bg-accent" : "bg-faint",
                    )}
                  />
                </Show>
              </button>
            );
          }}
        </For>
      </div>
      <Show when={mobile()}>
        <div class="flex items-center justify-between">
          <span class="text-[12px] text-muted">Par</span>
          {parSelector("h-[30px] w-9 flex-none")}
        </div>
      </Show>
    </Card>
  );
}

function ScoreCard(props: GolfProps) {
  const golf = props.golf;
  const state = golf.state;
  const mobile = () => props.layout() === "mobile";
  const par = () => golf.par(state.currentHole);
  const scored = () =>
    state.players.filter((player) => (player.scores[state.currentHole] ?? -1) >= 0).length;

  return (
    <Card class={twMerge("gap-3.5", props.class)}>
      <div class="flex items-center justify-between">
        <Label>{mobile() ? "Score" : `Score · Hole ${state.currentHole + 1} · Par ${par()}`}</Label>
        <Show when={!mobile()}>
          <span class="text-[11px] text-faint">
            {state.players.length === 0
              ? "0 players"
              : `${scored()} of ${state.players.length} scored`}
          </span>
        </Show>
      </div>
      <For
        each={state.players}
        fallback={
          <EmptyState
            icon="userPlus"
            title="No players yet"
            message={`Add up to ${maximumPlayers} players to start scoring. Scores show on stream as soon as the first one is in.`}
            class="flex-1"
          >
            <Button variant="accent" class="h-9 rounded-lg px-4" onClick={golf.addPlayer}>
              <Icon name="plus" size={14} stroke={2.2} />
              Add player
            </Button>
          </EmptyState>
        }
      >
        {(player, index) => {
          const score = () => player.scores[state.currentHole] ?? -1;
          const kind = () => scoreKind(score(), par());
          const buttons = (buttonClass: string) => (
            <>
              <Button
                variant="raised"
                class={twMerge("w-14 text-[14px]", buttonClass)}
                onClick={() => golf.adjustScore(index(), -1)}
              >
                −1
              </Button>
              <Button
                variant="raised"
                class={twMerge("w-16", buttonClass)}
                onClick={() => golf.setScore(index(), par())}
              >
                PAR
              </Button>
              <Button
                variant="raised"
                class={twMerge("w-14 text-[14px]", buttonClass)}
                onClick={() => golf.adjustScore(index(), 1)}
              >
                +1
              </Button>
            </>
          );
          return (
            <Show
              when={!mobile()}
              fallback={
                <div class="flex flex-col gap-3 rounded-xl border border-control-stroke bg-control p-3">
                  <div class="flex items-center gap-2.5">
                    <PlayerDot golf={golf} player={player} class="size-2" />
                    <span class="min-w-0 flex-1 truncate text-[14px]">{player.name}</span>
                    <span class={twMerge("text-[11px]", relativeClass(golf.relative(player)))}>
                      {formatRelativePar(golf.relative(player))}
                    </span>
                    <span
                      class={twMerge(
                        "w-8 text-right text-[22px] font-medium",
                        scoreStyles[kind()].text,
                      )}
                    >
                      {score() >= 0 ? score() : "–"}
                    </span>
                  </div>
                  <div class="flex gap-1.5">
                    {buttons("h-11 flex-1 basis-0 rounded-[10px] w-auto")}
                  </div>
                </div>
              }
            >
              <div class="flex items-center gap-3.5 rounded-xl border border-control-stroke bg-control px-3.5 py-3">
                <PlayerDot golf={golf} player={player} />
                <div class="flex min-w-0 flex-1 flex-col gap-0.5">
                  <span class="truncate text-[15px]">{player.name}</span>
                  <span class="text-[11px] text-muted">
                    {golf.strokes(player)} strokes · {formatRelativePar(golf.relative(player))}{" "}
                    overall
                  </span>
                </div>
                <div class="flex w-[84px] shrink-0 flex-col items-center gap-0.5">
                  <span
                    class={twMerge(
                      "text-[28px] font-medium",
                      score() >= 0 ? scoreStyles[kind()].text : "text-faint",
                    )}
                  >
                    {score() >= 0 ? score() : "–"}
                  </span>
                  <span
                    class={twMerge(
                      "text-[10px] whitespace-nowrap",
                      kind() === "par" ? "text-muted" : scoreStyles[kind()].text,
                    )}
                  >
                    {scoreName(score(), par())}
                  </span>
                </div>
                <div class="flex shrink-0 gap-1.5">{buttons("h-12 rounded-[10px]")}</div>
              </div>
            </Show>
          );
        }}
      </For>
    </Card>
  );
}

function RoundCard(props: GolfProps) {
  const golf = props.golf;
  const state = golf.state;
  return (
    <Card class={twMerge("gap-[18px]", props.class)}>
      <Label>Round</Label>
      <div class="flex gap-2">
        <TextField
          class="flex-1"
          value={state.title}
          placeholder="Round name"
          onCommit={golf.setTitle}
        />
        <Segmented
          itemClass="w-11 flex-none"
          options={[
            { value: 9, label: "9" },
            { value: 18, label: "18" },
          ]}
          value={state.numberOfHoles}
          onChange={golf.setNumberOfHoles}
        />
      </div>
      <div class="flex items-center justify-between">
        <Label>
          Players · {state.players.length} / {maximumPlayers}
        </Label>
        <div class="flex items-center gap-2">
          <span class="text-[12px] text-muted">Colors</span>
          <Toggle
            label="Player colors"
            checked={state.playerColors}
            onChange={golf.setPlayerColors}
          />
        </div>
      </div>
      <div class="flex flex-col gap-1.5">
        <For
          each={state.players}
          fallback={
            <div class="flex h-11 items-center justify-center rounded-[9px] border border-dashed border-control-stroke text-[12px] text-faint">
              No players in this round
            </div>
          }
        >
          {(player, index) => (
            <div class="flex items-center gap-2">
              <Show when={state.playerColors}>
                <ColorButton
                  value={rgbColorToHex(player.color)}
                  onChange={(color) => golf.setPlayerColor(index(), color)}
                />
              </Show>
              <TextField
                class="flex-1"
                value={player.name}
                placeholder="Name"
                onCommit={(name) => golf.setPlayerName(index(), name)}
              />
            </div>
          )}
        </For>
      </div>
      <div class="flex gap-2">
        <Button
          variant="dashed"
          class="h-9 flex-1 basis-0 rounded-lg text-[12px]"
          disabled={state.players.length >= maximumPlayers}
          onClick={golf.addPlayer}
        >
          + Add player
        </Button>
        <Button
          class="h-9 flex-1 basis-0 rounded-lg text-[12px] text-danger-fg"
          disabled={state.players.length === 0}
          onClick={golf.removeLastPlayer}
        >
          Remove last
        </Button>
      </div>
      <div class="flex-1" />
      <Button variant="dangerSoft" class="h-10" onClick={golf.newRound}>
        New round…
      </Button>
    </Card>
  );
}

function ScorecardTable(props: {
  golf: Golf;
  holes: number[];
  totalLabel: string;
  compact: boolean;
  strokesOnly: boolean;
}) {
  const golf = props.golf;
  const state = golf.state;
  const rowClass = () =>
    twMerge(
      "flex items-center border-b border-divider last:border-b-0",
      props.compact ? "gap-0.5 px-2 py-1" : "gap-[3px] px-3 py-[3px]",
    );
  const cellClass = () =>
    twMerge(
      "flex min-w-0 flex-1 basis-0 items-center justify-center rounded-md",
      props.compact ? "h-7 text-[11px]" : "h-9 text-[12px]",
    );
  const nameClass = () =>
    props.compact ? "w-[60px] shrink-0 text-[11px]" : "w-[120px] shrink-0 text-[12px]";
  const totalClass = () =>
    twMerge(
      "shrink-0 text-right font-semibold",
      props.compact ? "w-9 text-[11px]" : "w-[110px] text-[12px]",
    );
  const parTotal = () => props.holes.reduce((sum, hole) => sum + golf.par(hole), 0);

  return (
    <div class="flex flex-col rounded-[10px] border border-card-stroke bg-well-soft">
      <div class={rowClass()}>
        <div class={twMerge(nameClass(), "text-muted")}>HOLE</div>
        <For each={props.holes}>
          {(hole) => (
            <button
              type="button"
              class={twMerge(
                cellClass(),
                hole === state.currentHole ? "bg-accent font-semibold text-white" : "text-muted",
              )}
              onClick={() => golf.selectHole(hole)}
            >
              {hole + 1}
            </button>
          )}
        </For>
        <div class={twMerge(totalClass(), "text-muted")}>{props.totalLabel}</div>
      </div>
      <div class={rowClass()}>
        <div class={twMerge(nameClass(), "text-muted")}>Par</div>
        <For each={props.holes}>
          {(hole) => (
            <div
              class={twMerge(
                cellClass(),
                "text-muted",
                hole === state.currentHole && "bg-current-cell",
              )}
            >
              {golf.par(hole)}
            </div>
          )}
        </For>
        <div class={twMerge(totalClass(), "text-muted")}>{parTotal()}</div>
      </div>
      <For
        each={state.players}
        fallback={
          <div class="py-4 text-center text-[12px] text-faint">
            Player rows appear here once you add someone
          </div>
        }
      >
        {(player) => {
          const strokes = () =>
            props.holes.reduce((sum, hole) => sum + Math.max(0, player.scores[hole] ?? -1), 0);
          const relative = () => golf.relative(player);
          return (
            <div class={rowClass()}>
              <div class={twMerge(nameClass(), "flex min-w-0 items-center gap-1.5 tablet:gap-2")}>
                <PlayerDot
                  golf={golf}
                  player={player}
                  class={props.compact ? "size-1.5" : "size-2"}
                />
                <span class="truncate">{player.name}</span>
              </div>
              <For each={props.holes}>
                {(hole) => {
                  const score = () => player.scores[hole] ?? -1;
                  const kind = () => scoreKind(score(), golf.par(hole));
                  return (
                    <div
                      class={twMerge(
                        cellClass(),
                        scoreStyles[kind()].cell,
                        hole === state.currentHole &&
                          (kind() === "par" || kind() === "none") &&
                          "bg-current-cell",
                      )}
                    >
                      {score() >= 0 ? score() : ""}
                    </div>
                  );
                }}
              </For>
              <div
                class={twMerge(
                  totalClass(),
                  props.strokesOnly ? "text-fg" : relativeClass(relative()),
                )}
              >
                {props.strokesOnly
                  ? strokes() > 0
                    ? strokes()
                    : ""
                  : `${strokes()} · ${formatRelativePar(relative())}`}
              </div>
            </div>
          );
        }}
      </For>
    </div>
  );
}

function ScorecardCard(props: GolfProps) {
  const golf = props.golf;
  const state = golf.state;
  const split = () => props.layout() !== "desktop";
  return (
    <Card class={twMerge("gap-3.5", props.class)}>
      <div class="flex items-center justify-between gap-4">
        <Label>Scorecard</Label>
        <Show when={props.layout() === "desktop"}>
          <div class="flex gap-4">
            <For each={legend}>
              {([name, swatch]) => (
                <div class="flex items-center gap-1.5 text-[11px] text-muted">
                  <div class={twMerge("size-2.5 rounded-[3px] border", swatch)} />
                  {name}
                </div>
              )}
            </For>
          </div>
        </Show>
      </div>
      <Show
        when={split()}
        fallback={
          <ScorecardTable
            golf={golf}
            holes={holes(state.numberOfHoles)}
            totalLabel="TOTAL"
            compact={false}
            strokesOnly={false}
          />
        }
      >
        <ScorecardTable
          golf={golf}
          holes={holes(Math.min(9, state.numberOfHoles))}
          totalLabel={state.numberOfHoles > 9 ? "OUT" : "TOT"}
          compact
          strokesOnly
        />
        <Show when={state.numberOfHoles > 9}>
          <ScorecardTable
            golf={golf}
            holes={holes(state.numberOfHoles - 9, 9)}
            totalLabel="IN"
            compact
            strokesOnly
          />
        </Show>
      </Show>
    </Card>
  );
}

export function GolfPage(props: PageProps) {
  const golf = createGolf(props.remote, props.confirm);
  const golfProps = { ...props, golf };
  return (
    <Switch>
      <Match when={props.layout() === "desktop"}>
        <div class="flex flex-col gap-4">
          <HoleCard {...golfProps} />
          <div class="flex gap-4">
            <ScoreCard {...golfProps} class="flex-1" />
            <RoundCard {...golfProps} class="w-[400px] shrink-0" />
          </div>
          <ScorecardCard {...golfProps} />
        </div>
      </Match>
      <Match when={props.layout() === "tablet"}>
        <div class="flex flex-col gap-4">
          <HoleCard {...golfProps} />
          <ScoreCard {...golfProps} />
          <div class="flex gap-4">
            <ScorecardCard {...golfProps} class="min-w-0 flex-1 basis-0" />
            <RoundCard {...golfProps} class="min-w-0 flex-1 basis-0" />
          </div>
        </div>
      </Match>
      <Match when={props.layout() === "mobile"}>
        <div class="flex flex-col gap-3">
          <HoleCard {...golfProps} />
          <ScoreCard {...golfProps} />
          <ScorecardCard {...golfProps} />
          <RoundCard {...golfProps} />
        </div>
      </Match>
    </Switch>
  );
}
