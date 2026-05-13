import { createSignal, onMount, onCleanup } from "solid-js";
import { render } from "solid-js/web";
import {
  createScoreboardTeam,
  EventData,
  RemoteControlScoreboardTeam,
  WebSocketConnection,
} from "./utils.ts";

interface TeamColumnProps {
  team: RemoteControlScoreboardTeam;
}

function TeamColumn(props: TeamColumnProps) {
  return (
    <div class="team-column" style={{ "background-color": props.team.bgColor }}>
      <div class="score-container">
        <div class="set-score" style={{ color: props.team.textColor }}>
          {props.team.primaryScore}
        </div>
      </div>
      <div class="info-bar" style={{ "background-color": props.team.bgColor }}>
        <div class="match-box" style={{ color: props.team.textColor }}>
          {props.team.secondaryScore}
        </div>
        <div class="team-name" style={{ color: props.team.textColor }}>
          {props.team.name}
        </div>
        <div class="serve-box">
          <img
            src="/volleyball.png"
            class="serve-img"
            classList={{ hidden: !props.team.possession }}
          />
        </div>
      </div>
    </div>
  );
}

function App() {
  const [team1, setTeam1] = createSignal(createScoreboardTeam());
  const [team2, setTeam2] = createSignal(createScoreboardTeam());

  class ScoreboardConnection extends WebSocketConnection {
    handleEvent(data: EventData): void {
      if (data.scoreboard !== undefined) {
        const config = data.scoreboard.config;
        if (config.team1) setTeam1(config.team1);
        if (config.team2) setTeam2(config.team2);
      }
    }
  }

  const _connection = new ScoreboardConnection();

  function toggleFullscreen() {
    if (!document.fullscreenElement) {
      document.documentElement.requestFullscreen();
    } else {
      document.exitFullscreen();
    }
  }

  onMount(() => {
    document.body.addEventListener("click", toggleFullscreen);
  });

  onCleanup(() => {
    document.body.removeEventListener("click", toggleFullscreen);
  });

  return (
    <div class="flex">
      <TeamColumn team={team1()} />
      <TeamColumn team={team2()} />
    </div>
  );
}

render(() => <App />, document.getElementById("app")!);
