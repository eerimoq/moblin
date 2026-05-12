import { createSignal, onMount, onCleanup } from "solid-js";
import type { Accessor } from "solid-js";
import { render } from "solid-js/web";
import { EventData, WebSocketConnection } from "./utils.ts";

interface Team {
  bgColor: string;
  textColor: string;
  primaryScore: string;
  name: string;
  secondaryScore: string;
  possession: boolean;
}

const defaultTeam: Team = {
  bgColor: "#000000",
  textColor: "#ffffff",
  primaryScore: "0",
  name: "TEAM",
  secondaryScore: "0",
  possession: false,
};

interface TeamColumnProps {
  team: Accessor<Team>;
}

function TeamColumn({ team }: TeamColumnProps) {
  return (
    <div class="team-column" style={{ "background-color": team().bgColor }}>
      <div class="score-container">
        <div class="set-score" style={{ color: team().textColor }}>
          {team().primaryScore}
        </div>
      </div>
      <div class="info-bar" style={{ "background-color": team().bgColor }}>
        <div class="match-box" style={{ color: team().textColor }}>
          {team().secondaryScore}
        </div>
        <div class="team-name" style={{ color: team().textColor }}>
          {team().name}
        </div>
        <div class="serve-box">
          <img src="/volleyball.png" class="serve-img" classList={{ hidden: !team().possession }} />
        </div>
      </div>
    </div>
  );
}

function App() {
  const [team1, setTeam1] = createSignal({ ...defaultTeam, name: "TEAM 1" });
  const [team2, setTeam2] = createSignal({ ...defaultTeam, name: "TEAM 2" });

  class ScoreboardConnection extends WebSocketConnection {
    handleEvent(data: EventData): void {
      if (data.scoreboard !== undefined) {
        const config = data.scoreboard.config;
        if (config.team1) setTeam1({ ...config.team1 });
        if (config.team2) setTeam2({ ...config.team2 });
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
      <TeamColumn team={team1} />
      <TeamColumn team={team2} />
    </div>
  );
}

render(() => <App />, document.getElementById("app")!);
