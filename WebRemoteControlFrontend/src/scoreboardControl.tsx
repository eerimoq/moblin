import { For, Match, Show, Switch } from "solid-js";
import { twMerge } from "tailwind-merge";
import type { PageProps } from "./app.tsx";
import {
  Button,
  Card,
  ColorButton,
  Label,
  Segmented,
  Select,
  StatusDot,
  Switch as Toggle,
  TextField,
} from "./components.tsx";
import type { Remote } from "./remote.ts";
import type {
  RemoteControlScoreboardTeam,
  ScoreboardControlDef,
  ScoreboardMatchConfig,
} from "./utils.ts";

const controlOrder = [
  "secondaryScore",
  "currentSetScore",
  "stat1",
  "stat2",
  "stat3",
  "stat4",
  "possession",
];

const layouts = [
  { value: "stacked", label: "Stacked" },
  { value: "stackedInline", label: "Inline" },
  { value: "sideBySide", label: "Side" },
  { value: "stackHistory", label: "History" },
];

const abbreviations: Record<string, string> = {
  TO: "Timeouts",
  FOUL: "Fouls",
  Set: "Sets",
  Game: "Games",
  SERVE: "Serve",
  POSS: "Possession",
};

const periods: Record<string, [string, string, string]> = {
  SET: ["Sets", "set", "Set "],
  QTR: ["Quarters", "quarter", "Q"],
  PER: ["Periods", "period", "P"],
  HALF: ["Halves", "half", "H"],
};

type TeamKey = "team1" | "team2";

type SecondaryScoreKey =
  | "secondaryScore1"
  | "secondaryScore2"
  | "secondaryScore3"
  | "secondaryScore4"
  | "secondaryScore5";

function makeTeamKey(teamNumber: number): TeamKey {
  return `team${teamNumber}` as TeamKey;
}

function makeOtherTeamKey(teamNumber: number): TeamKey {
  return makeTeamKey(teamNumber === 1 ? 2 : 1);
}

function makeSecondaryScoreKey(scoreNumber: number): SecondaryScoreKey {
  return `secondaryScore${scoreNumber}` as SecondaryScoreKey;
}

function titleCase(text: string): string {
  return text.charAt(0).toUpperCase() + text.slice(1).toLowerCase();
}

function period(config: ScoreboardMatchConfig): {
  plural: string;
  singular: string;
  column: (n: number) => string;
} {
  const label = config.global.periodLabel;
  const [plural, singular, prefix] = periods[label] ?? [
    label ? titleCase(label) : "Periods",
    label ? label.toLowerCase() : "period",
    label ? `${titleCase(label)} ` : "",
  ];
  return {
    plural,
    singular,
    column: (n) => (label === "QTR" && n === 5 ? "OT" : `${prefix}${n}`),
  };
}

function controlLabel(key: string, control: ScoreboardControlDef): string {
  if (control.label) return abbreviations[control.label] ?? control.label;
  const option = control.options?.find((value) => !value.startsWith("NO ") && value !== "NONE");
  return option !== undefined ? titleCase(option) : key;
}

function optionLabels(options: string[]): string[] {
  if (options.length === 2 && options[0].startsWith("NO ")) return ["Off", "On"];
  return options.map((option) =>
    option.startsWith("NO ") || option === "NONE"
      ? "None"
      : /^\d+$/.test(option)
        ? option
        : titleCase(option),
  );
}

function possessionTexts(control: ScoreboardControlDef): [string, string, string] {
  return control.label === "SERVE"
    ? ["SERVING", "Serving", "Give serve"]
    : ["HAS BALL", "Has ball", "Give ball"];
}

function pointLabel(config: ScoreboardMatchConfig): string {
  const label = config.controls.primaryScore?.label ?? "Pt";
  return label === "Pt" ? "POINT" : label.toUpperCase();
}

function secondaryDisplay(config: ScoreboardMatchConfig, team: RemoteControlScoreboardTeam) {
  if (config.global.scoringMode === "tennis") {
    return {
      label: "GAMES",
      value: team[makeSecondaryScoreKey(parseInt(config.global.period) || 1)] || "0",
    };
  }
  if (config.controls.secondaryScore === undefined) return undefined;
  const label = config.controls.secondaryScore.label ?? "";
  return {
    label: (abbreviations[label] ?? label).toUpperCase(),
    value: team.secondaryScore || "0",
  };
}

function createActions(remote: Remote, confirm: PageProps["confirm"]) {
  const state = remote.scoreboard;
  const setState = remote.setScoreboard;

  function send(): void {
    remote.connection.sendUpdateScoreboard(state);
  }

  function adjust(teamNumber: number, key: string, delta: number): void {
    const teamKey = makeTeamKey(teamNumber);
    const team = state[teamKey];
    if (state.global.scoringMode === "tennis" && key === "primaryScore") {
      adjustTennis(teamNumber, delta);
      return;
    }
    if (key === "currentSetScore") {
      const setNumber = parseInt(state.global.period) || 1;
      if (setNumber >= 1 && setNumber <= 5) {
        const actualKey = makeSecondaryScoreKey(setNumber);
        const current = parseInt(team[actualKey] ?? "0") || 0;
        setState(teamKey, actualKey, Math.max(0, current + delta).toString());
        const otherTeamKey = makeOtherTeamKey(teamNumber);
        if (!state[otherTeamKey][actualKey]) {
          setState(otherTeamKey, actualKey, "0");
        }
      }
      send();
      return;
    }
    const current = parseInt(team[key] as string) || 0;
    setState(teamKey, key, Math.max(0, current + delta).toString());
    if (key === "primaryScore" && delta > 0 && state.global.changePossessionOnScore) {
      setPossession(teamNumber);
      return;
    }
    send();
  }

  function adjustTennis(teamNumber: number, delta: number): void {
    const teamKey = makeTeamKey(teamNumber);
    const otherTeamKey = makeOtherTeamKey(teamNumber);
    let score = state[teamKey].primaryScore;
    const otherScore = state[otherTeamKey].primaryScore;
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
            setState(otherTeamKey, "primaryScore", "D");
          } else {
            score = "40";
          }
          break;
        case "40":
          if (otherScore === "Ad") {
            score = "D";
            setState(otherTeamKey, "primaryScore", "D");
          } else if (otherScore === "40" || otherScore === "D") {
            score = "Ad";
          } else {
            winGame(teamNumber);
            return;
          }
          break;
        case "D":
          if (otherScore === "Ad") {
            setState(otherTeamKey, "primaryScore", "D");
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
    setState(teamKey, "primaryScore", score);
    send();
  }

  function winGame(teamNumber: number): void {
    setState("team1", "primaryScore", "0");
    setState("team2", "primaryScore", "0");
    const nextServer = state.team1.possession ? 2 : 1;
    setState("team1", "possession", nextServer === 1);
    setState("team2", "possession", nextServer === 2);
    adjust(teamNumber, "currentSetScore", 1);
  }

  function setPossession(teamNumber: number): void {
    setState("team1", "possession", teamNumber === 1);
    setState("team2", "possession", teamNumber === 2);
    send();
  }

  function setTeamValue(teamNumber: number, key: string, value: string): void {
    setState(makeTeamKey(teamNumber), key, value);
    send();
  }

  function setHistoricScore(teamNumber: number, setNumber: number, score: string): void {
    const actualKey = makeSecondaryScoreKey(setNumber);
    setState(makeTeamKey(teamNumber), actualKey, score);
    if (score !== "") {
      const otherTeamKey = makeOtherTeamKey(teamNumber);
      if (!state[otherTeamKey][actualKey]) {
        setState(otherTeamKey, actualKey, "0");
      }
    }
    send();
  }

  function setGlobal(key: string, value: string | boolean): void {
    setState("global", key, value);
    send();
  }

  function setLayout(layout: string): void {
    setState("layout", layout);
    send();
  }

  function startNextPeriod(): void {
    if (state.global.scoringMode === "tennis") {
      const current = parseInt(state.global.period) || 0;
      setState("global", "period", (current + 1).toString());
      setState("team1", "primaryScore", "0");
      setState("team2", "primaryScore", "0");
      send();
      return;
    }
    let slot = -1;
    for (let setIndex = 1; setIndex <= 5; setIndex++) {
      const key = makeSecondaryScoreKey(setIndex);
      if (!state.team1[key] && !state.team2[key]) {
        slot = setIndex;
        break;
      }
    }
    if (slot !== -1) {
      const team1Score = state.team1.primaryScore;
      const team2Score = state.team2.primaryScore;
      const key = makeSecondaryScoreKey(slot);
      setState("team1", key, team1Score || "0");
      setState("team2", key, team2Score || "0");
    }
    const current = parseInt(state.global.period) || 0;
    setState("global", "period", (current + 1).toString());
    for (const controlKey of Object.keys(state.controls)) {
      const control = state.controls[controlKey];
      if (!control.periodReset) continue;
      if (control.type === "toggleTeam") {
        setState("team1", controlKey, false);
        setState("team2", controlKey, false);
        continue;
      }
      const reset = control.options && control.options.length > 0 ? control.options[0] : "0";
      setState("team1", controlKey, reset);
      setState("team2", controlKey, reset);
    }
    if (state.global.primaryScoreResetOnPeriod) {
      setState("team1", "primaryScore", "0");
      setState("team2", "primaryScore", "0");
    }
    send();
  }

  function nextPeriod(): void {
    const { singular } = period(state);
    const next = (parseInt(state.global.period) || 0) + 1;
    confirm({
      title: `Start ${singular} ${next}?`,
      message:
        state.global.scoringMode === "tennis"
          ? "Resets the points of the current game."
          : `Saves the current scores to the ${singular} history and resets the counters that restart every ${singular}.`,
      confirmLabel: `Start ${singular} ${next}`,
      confirmVariant: "accent",
      onConfirm: startNextPeriod,
    });
  }

  function clearMatch(): void {
    if (state.global.timerDirection === "up") {
      setState("global", "timer", "0:00");
    } else {
      setState("global", "timer", `${parseInt(state.global.duration) || 0}:00`);
    }
    setState("global", "period", "1");
    for (const controlKey of Object.keys(state.controls)) {
      const control = state.controls[controlKey];
      if (control.type === "toggleTeam") {
        setState("team1", "possession", true);
        setState("team2", "possession", false);
        continue;
      }
      const reset = control.options && control.options.length > 0 ? control.options[0] : "0";
      setState("team1", controlKey, reset);
      setState("team2", controlKey, reset);
    }
    setState("team1", "primaryScore", "0");
    setState("team2", "primaryScore", "0");
    const hasSecondary = !!state.team1.secondaryScore;
    setState("team1", "secondaryScore", hasSecondary ? "0" : "");
    setState("team2", "secondaryScore", hasSecondary ? "0" : "");
    for (let setIndex = 1; setIndex <= 5; setIndex++) {
      const key = makeSecondaryScoreKey(setIndex);
      setState("team1", key, "");
      setState("team2", key, "");
    }
    send();
  }

  function newMatch(): void {
    const team1 = state.team1.name || "Home";
    const team2 = state.team2.name || "Away";
    confirm({
      title: "New match?",
      message: `Clears scores, ${period(state).singular} history, stats and the clock for ${team1} and ${team2}. Team names and colors are kept.`,
      cancelLabel: "Keep match",
      confirmLabel: "Clear & start",
      onConfirm: clearMatch,
    });
  }

  return {
    adjust,
    setPossession,
    setTeamValue,
    setHistoricScore,
    setGlobal,
    setLayout,
    nextPeriod,
    newMatch,
  };
}

type Actions = ReturnType<typeof createActions>;

function ControlRow(props: {
  teamNumber: number;
  controlKey: string;
  control: ScoreboardControlDef;
  team: RemoteControlScoreboardTeam;
  actions: Actions;
}) {
  const value = () => (props.team[props.controlKey] as string) ?? "";
  const options = () => props.control.options ?? [];
  const numeric = () => options().length > 0 && options().every((option) => /^\d+$/.test(option));

  function step(delta: number): void {
    const index = Math.max(0, options().indexOf(value()));
    const next = Math.min(options().length - 1, Math.max(0, index + delta));
    props.actions.setTeamValue(props.teamNumber, props.controlKey, options()[next]);
  }

  return (
    <div class="flex items-center gap-2">
      <Label class="w-24 shrink-0">{controlLabel(props.controlKey, props.control)}</Label>
      <Switch>
        <Match when={props.control.type === "counter"}>
          <Button
            variant="raised"
            class="h-10 flex-1 basis-0"
            onClick={() => props.actions.adjust(props.teamNumber, props.controlKey, -1)}
          >
            −1 {props.control.label}
          </Button>
          <Button
            variant="raised"
            class="h-10 flex-1 basis-0"
            onClick={() => props.actions.adjust(props.teamNumber, props.controlKey, 1)}
          >
            +1 {props.control.label}
          </Button>
        </Match>
        <Match when={props.control.type === "toggleTeam"}>
          <Button
            variant={props.team.possession ? "selected" : "raised"}
            class="h-10 flex-1"
            onClick={() => props.actions.setPossession(props.teamNumber)}
          >
            <div
              class={twMerge(
                "size-2 rounded-full",
                props.team.possession ? "bg-accent" : "border border-faint",
              )}
            />
            {props.team.possession
              ? possessionTexts(props.control)[1]
              : possessionTexts(props.control)[2]}
          </Button>
        </Match>
        <Match when={props.control.type === "cycle" && numeric()}>
          <Button variant="raised" class="h-10 w-14 text-[14px]" onClick={() => step(-1)}>
            −
          </Button>
          <div class="flex h-10 flex-1 items-center justify-center gap-2 rounded-[9px] border border-control-stroke bg-control">
            <span class="text-[15px] font-semibold">{value() || options()[0]}</span>
            <span class="text-[11px] text-hint">/ {options()[options().length - 1]}</span>
          </div>
          <Button variant="raised" class="h-10 w-14 text-[14px]" onClick={() => step(1)}>
            +
          </Button>
        </Match>
        <Match when={props.control.type === "select" || props.control.type === "cycle"}>
          <Segmented
            class="flex-1"
            options={options().map((option, index) => ({
              value: option,
              label: optionLabels(options())[index],
            }))}
            value={value()}
            onChange={(option) =>
              props.actions.setTeamValue(props.teamNumber, props.controlKey, option)
            }
          />
        </Match>
      </Switch>
    </div>
  );
}

function TeamCard(props: PageProps & { teamNumber: number; actions: Actions }) {
  const config = () => props.remote.scoreboard;
  const team = () => config()[makeTeamKey(props.teamNumber)];
  const possession = () => config().controls.possession;
  const secondary = () => secondaryDisplay(config(), team());
  const controls = () =>
    controlOrder.filter((key) => config().controls[key] !== undefined && key !== "primaryScore");
  const desktop = () => props.layout() === "desktop";

  return (
    <Card class="gap-4">
      <div class="flex items-center justify-between">
        <Label>{props.teamNumber === 1 ? "Home" : "Away"}</Label>
        <StatusDot
          class={twMerge(
            "text-accent",
            !(possession() !== undefined && team().possession) && "opacity-0",
          )}
        >
          {possession() !== undefined ? possessionTexts(possession()!)[0] : ""}
        </StatusDot>
      </div>
      <div class="flex items-center gap-2">
        <TextField
          class="flex-1"
          value={team().name}
          placeholder="Team name"
          onCommit={(name) => props.actions.setTeamValue(props.teamNumber, "name", name)}
        />
        <ColorButton
          value={team().bgColor}
          label={desktop() ? "Fill" : undefined}
          onChange={(color) => props.actions.setTeamValue(props.teamNumber, "bgColor", color)}
        />
        <ColorButton
          value={team().textColor}
          label={desktop() ? "Text" : undefined}
          onChange={(color) => props.actions.setTeamValue(props.teamNumber, "textColor", color)}
        />
      </div>
      <div class="flex h-32 gap-2 desktop:h-[156px]">
        <div
          class="flex min-w-0 flex-1 overflow-hidden rounded-xl"
          style={{ "background-color": team().bgColor, color: team().textColor }}
        >
          <div class="flex min-w-0 flex-1 items-center justify-center text-[72px] leading-none font-semibold tracking-[-0.04em] desktop:text-[96px]">
            {team().primaryScore}
          </div>
          <Show when={secondary()}>
            {(display) => (
              <div class="flex w-[76px] shrink-0 flex-col items-center justify-center gap-1 bg-black/28">
                <div class="text-[10px] tracking-[0.08em] opacity-70">{display().label}</div>
                <div class="text-[32px] leading-9 font-semibold">{display().value}</div>
              </div>
            )}
          </Show>
        </div>
        <div class="flex w-[104px] shrink-0 flex-col gap-2 desktop:w-[132px]">
          <Button
            variant="raised"
            class="flex-1 flex-col gap-0.5 rounded-xl"
            onClick={() => props.actions.adjust(props.teamNumber, "primaryScore", 1)}
          >
            <span class="text-[28px] leading-[34px] font-medium">+1</span>
            <span class="text-[10px] tracking-[0.08em] text-muted">{pointLabel(config())}</span>
          </Button>
          <Button
            variant="raised"
            class="h-11 rounded-[10px] text-[14px]"
            onClick={() => props.actions.adjust(props.teamNumber, "primaryScore", -1)}
          >
            −1
          </Button>
        </div>
      </div>
      <Show when={controls().length > 0}>
        <div class="flex flex-col gap-2">
          <For each={controls()}>
            {(key) => (
              <ControlRow
                teamNumber={props.teamNumber}
                controlKey={key}
                control={config().controls[key]}
                team={team()}
                actions={props.actions}
              />
            )}
          </For>
        </div>
      </Show>
    </Card>
  );
}

function HistoryCard(props: PageProps & { actions: Actions }) {
  const config = () => props.remote.scoreboard;
  const current = () => parseInt(config().global.period) || 1;
  const names = () => period(config());
  const mobile = () => props.layout() === "mobile";

  function setCurrent(value: number): void {
    props.actions.setGlobal("period", String(Math.max(1, value)));
  }

  function TeamRow(rowProps: { teamNumber: number }) {
    const team = () => config()[makeTeamKey(rowProps.teamNumber)];
    const other = () => config()[makeOtherTeamKey(rowProps.teamNumber)];
    return (
      <div class="flex items-center gap-1.5">
        <div class="flex w-24 min-w-0 items-center gap-2.5 tablet:w-40 tablet:pl-3">
          <div
            class="size-2.5 shrink-0 rounded-[3px]"
            style={{ "background-color": team().bgColor }}
          />
          <span class="truncate text-[12px] tablet:text-[13px]">{team().name}</span>
        </div>
        <For each={[1, 2, 3, 4, 5]}>
          {(setNumber) => {
            const key = makeSecondaryScoreKey(setNumber);
            const value = () => team()[key] ?? "";
            const otherValue = () => other()[key] ?? "";
            const live = () => setNumber === current();
            const won = () =>
              value() !== "" && (parseInt(value()) || 0) > (parseInt(otherValue()) || 0);
            const livePlaceholder = () =>
              live() && config().global.primaryScoreResetOnPeriod ? team().primaryScore : "–";
            return (
              <input
                type="text"
                inputMode="numeric"
                aria-label={`${team().name} ${names().column(setNumber)}`}
                class={twMerge(
                  "h-11 min-w-0 flex-1 basis-0 rounded-[9px] border border-control-stroke bg-control text-center text-[15px] text-muted outline-none placeholder:text-faint focus:border-accent",
                  won() && "font-semibold text-fg",
                  live() && "border-accent bg-raised font-semibold text-fg placeholder:text-fg",
                )}
                value={value()}
                placeholder={livePlaceholder()}
                onKeyDown={(event) => {
                  if (event.key === "Enter") event.currentTarget.blur();
                }}
                onChange={(event) => {
                  const text = event.currentTarget.value.trim();
                  const parsed = parseInt(text);
                  props.actions.setHistoricScore(
                    rowProps.teamNumber,
                    setNumber,
                    text === "" || isNaN(parsed) ? "" : String(Math.max(0, parsed)),
                  );
                }}
              />
            );
          }}
        </For>
      </div>
    );
  }

  return (
    <Card class="gap-3.5">
      <div class="flex h-9 items-center justify-between gap-3">
        <div class="flex min-w-0 items-center gap-3">
          <Label>{names().plural}</Label>
          <Show when={!mobile()}>
            <span class="truncate text-[11px] text-hint">
              Tap a {names().singular} to make it current · tap a score to fix it
            </span>
          </Show>
        </div>
        <div class="flex shrink-0 items-center gap-2">
          <span class="text-[12px] text-muted">
            {mobile() ? "Current" : `Current ${names().singular}`}
          </span>
          <div class="flex items-center gap-0.5 rounded-[9px] border border-control-stroke bg-control p-[3px]">
            <button
              type="button"
              class="h-7 w-8 rounded-md text-[13px] text-fg-3 active:bg-selected"
              onClick={() => setCurrent(current() - 1)}
            >
              −
            </button>
            <div class="w-10 text-center text-[13px] font-semibold">{current()}</div>
            <button
              type="button"
              class="h-7 w-8 rounded-md text-[13px] text-fg-3 active:bg-selected"
              onClick={() => setCurrent(current() + 1)}
            >
              +
            </button>
          </div>
        </div>
      </div>
      <div class="flex flex-col gap-1.5">
        <div class="flex items-center gap-1.5">
          <div class="w-24 text-[11px] tracking-[0.04em] text-muted tablet:w-40 tablet:pl-3">
            {mobile() ? "" : "TEAM"}
          </div>
          <For each={[1, 2, 3, 4, 5]}>
            {(setNumber) => (
              <button
                type="button"
                class={twMerge(
                  "flex h-8 min-w-0 flex-1 basis-0 items-center justify-center rounded-lg text-[12px] whitespace-nowrap",
                  setNumber === current()
                    ? "bg-accent font-semibold text-white"
                    : "text-fg-3 active:bg-selected",
                )}
                onClick={() => setCurrent(setNumber)}
              >
                {mobile()
                  ? names().column(setNumber).replace(/^\D+ /, "")
                  : `${names().column(setNumber)}${setNumber === current() ? " · live" : ""}`}
              </button>
            )}
          </For>
        </div>
        <TeamRow teamNumber={1} />
        <TeamRow teamNumber={2} />
      </div>
      <Show when={mobile()}>
        <div class="text-[11px] text-hint">Tap a {names().singular} or a score to change it</div>
      </Show>
    </Card>
  );
}

function MatchCard(props: PageProps & { actions: Actions; class?: string }) {
  const config = () => props.remote.scoreboard;
  const global = () => config().global;

  function ShowToggle(showProps: {
    label: string;
    checked: boolean;
    onChange: (on: boolean) => void;
  }) {
    return (
      <>
        <Toggle label={showProps.label} checked={showProps.checked} onChange={showProps.onChange} />
        <span class={twMerge("text-[12px]", showProps.checked ? "text-fg" : "text-fg-3")}>
          {showProps.label}
        </span>
      </>
    );
  }

  return (
    <Card class={twMerge("gap-3.5", props.class)}>
      <Label>Match</Label>
      <Select
        prefix="Sport"
        options={props.remote.sports().map((sport) => ({ value: sport, label: titleCase(sport) }))}
        value={config().sportId}
        onChange={(sport) => props.remote.connection.sendSetScoreboardSport(sport)}
      />
      <Segmented options={layouts} value={config().layout} onChange={props.actions.setLayout} />
      <div class="flex flex-col gap-2 pt-1">
        <Label class="pb-0.5">Show on stream</Label>
        <div class="flex items-center gap-2">
          <div class="flex w-[92px] shrink-0 items-center gap-2">
            <ShowToggle
              label="Title"
              checked={!!global().showTitle}
              onChange={(on) => props.actions.setGlobal("showTitle", on)}
            />
          </div>
          <TextField
            class="h-9 flex-1 rounded-lg text-[12px]"
            value={global().title}
            placeholder="Title"
            onCommit={(title) => props.actions.setGlobal("title", title)}
          />
        </div>
        <div class="flex items-center gap-2">
          <div class="flex w-[92px] shrink-0 items-center gap-2">
            <ShowToggle
              label="Info"
              checked={!!global().showStats}
              onChange={(on) => props.actions.setGlobal("showStats", on)}
            />
          </div>
          <TextField
            class="h-9 flex-1 rounded-lg text-[12px]"
            value={global().infoBoxText}
            placeholder="Info box text"
            onCommit={(text) => props.actions.setGlobal("infoBoxText", text)}
          />
        </div>
        <div class="flex gap-2">
          <div class="flex h-9 flex-1 basis-0 items-center gap-2 rounded-lg border border-control-stroke bg-control px-2.5">
            <ShowToggle
              label="More stats"
              checked={!!global().showMoreStats}
              onChange={(on) => props.actions.setGlobal("showMoreStats", on)}
            />
          </div>
          <div class="flex h-9 flex-1 basis-0 items-center gap-2 rounded-lg border border-control-stroke bg-control px-2.5">
            <ShowToggle
              label="Clock"
              checked={!!global().showClock}
              onChange={(on) => props.actions.setGlobal("showClock", on)}
            />
          </div>
        </div>
      </div>
      <div class="min-h-3 flex-1" />
      <div class="flex gap-2">
        <Button variant="raised" class="h-10 flex-1 basis-0" onClick={props.actions.nextPeriod}>
          Next {period(config()).singular} →
        </Button>
        <Button variant="dangerSoft" class="h-10 flex-1 basis-0" onClick={props.actions.newMatch}>
          New match…
        </Button>
      </div>
      <a
        href="/scoreboard.html"
        target="_blank"
        class="self-center text-[11px] text-muted underline-offset-2 hover:underline"
      >
        Open full screen scoreboard display ↗
      </a>
    </Card>
  );
}

function ClockCard(props: PageProps & { actions: Actions; class?: string }) {
  const remote = props.remote;
  const global = () => remote.scoreboard.global;
  const running = remote.clockRunning;

  return (
    <Card class={twMerge("gap-3.5", props.class)}>
      <div class="flex h-9 items-center justify-between">
        <Label>Clock</Label>
        <StatusDot class={running() ? "text-accent" : "text-muted"}>
          {running() ? "RUNNING" : "STOPPED"}
        </StatusDot>
      </div>
      <div class="flex gap-2">
        <input
          type="text"
          inputMode="numeric"
          aria-label="Clock"
          class="h-14 min-w-0 flex-1 rounded-[10px] border border-control-stroke bg-control px-4 text-[28px] font-medium tracking-[-0.02em] outline-none focus:border-accent"
          value={global().timer}
          placeholder="0:00"
          onKeyDown={(event) => {
            if (event.key === "Enter") event.currentTarget.blur();
          }}
          onChange={(event) => remote.connection.sendSetScoreboardClock(event.currentTarget.value)}
        />
        <Button
          variant="raised"
          class="h-14 w-[120px] rounded-[10px]"
          onClick={() => {
            remote.setClockRunning(!running());
            remote.connection.sendToggleClock();
          }}
        >
          <Show
            when={running()}
            fallback={
              <svg width="12" height="12" viewBox="0 0 12 12" fill="currentColor">
                <path d="M2 1l9 5-9 5z" />
              </svg>
            }
          >
            <div class="flex gap-[3px]">
              <div class="h-3 w-[3px] rounded-[1px] bg-current" />
              <div class="h-3 w-[3px] rounded-[1px] bg-current" />
            </div>
          </Show>
          {running() ? "Pause" : "Start"}
        </Button>
      </div>
      <div class="flex gap-2">
        <Select
          class="flex-1"
          prefix="Length"
          options={Array.from({ length: 120 }, (_, index) => ({
            value: String(index + 1),
            label: `${index + 1} min`,
          }))}
          value={String(global().duration)}
          onChange={(minutes) => remote.connection.setScoreboardDuration(parseInt(minutes))}
        />
        <Segmented
          class="w-[140px]"
          options={[
            { value: "up", label: "Up ↑" },
            { value: "down", label: "Down ↓" },
          ]}
          value={global().timerDirection}
          onChange={(direction) => props.actions.setGlobal("timerDirection", direction)}
        />
      </div>
    </Card>
  );
}

export function ScoreboardPage(props: PageProps) {
  const actions = createActions(props.remote, props.confirm);
  const hasHistory = () => props.remote.scoreboard.global.period !== "";
  const team = (teamNumber: number) => (
    <TeamCard {...props} teamNumber={teamNumber} actions={actions} />
  );
  const history = () => (
    <Show when={hasHistory()}>
      <HistoryCard {...props} actions={actions} />
    </Show>
  );

  return (
    <Switch>
      <Match when={props.layout() === "desktop"}>
        <div class="flex flex-col gap-4">
          <div class="flex gap-4">
            <div class="flex min-w-0 flex-1 basis-0 *:flex-1">{team(1)}</div>
            <div class="flex min-w-0 flex-1 basis-0 *:flex-1">{team(2)}</div>
            <MatchCard {...props} actions={actions} class="w-[400px] shrink-0" />
          </div>
          <div class="flex gap-4">
            <div class="flex min-w-0 flex-1 *:flex-1">{history()}</div>
            <ClockCard {...props} actions={actions} class="w-[400px] shrink-0" />
          </div>
        </div>
      </Match>
      <Match when={props.layout() === "tablet"}>
        <div class="flex flex-col gap-4">
          <div class="flex gap-4">
            <div class="flex min-w-0 flex-1 basis-0 *:flex-1">{team(1)}</div>
            <div class="flex min-w-0 flex-1 basis-0 *:flex-1">{team(2)}</div>
          </div>
          {history()}
          <div class="flex items-start gap-4">
            <MatchCard {...props} actions={actions} class="min-w-0 flex-1 basis-0" />
            <ClockCard {...props} actions={actions} class="min-w-0 flex-1 basis-0" />
          </div>
        </div>
      </Match>
      <Match when={props.layout() === "mobile"}>
        <div class="flex flex-col gap-3">
          {team(1)}
          {team(2)}
          {history()}
          <MatchCard {...props} actions={actions} />
          <ClockCard {...props} actions={actions} />
        </div>
      </Match>
    </Switch>
  );
}
