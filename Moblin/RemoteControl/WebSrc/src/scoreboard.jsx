import { createSignal, onMount, onCleanup } from "solid-js";
import { render } from "solid-js/web";
import { websocketUrl } from "./utils.js";

const defaultTeam = {
  bgColor: "#000000",
  textColor: "#ffffff",
  primaryScore: "0",
  name: "TEAM",
  secondaryScore: "0",
  possession: false,
};

function TeamColumn({ team }) {
  return (
    <div
      class="team-column"
      style={{ "background-color": team().bgColor }}
    >
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
          <img
            src="/volleyball.png"
            class="serve-img"
            classList={{ hidden: !team().possession }}
          />
        </div>
      </div>
    </div>
  );
}

function App() {
  const [team1, setTeam1] = createSignal({ ...defaultTeam, name: "TEAM 1" });
  const [team2, setTeam2] = createSignal({ ...defaultTeam, name: "TEAM 2" });

  let ws = null;

  function connect() {
    ws = new WebSocket(websocketUrl());
    ws.onclose = () => setTimeout(connect, 3000);
    ws.onmessage = (e) => {
      const message = JSON.parse(e.data);
      if (message.event !== undefined) {
        handleEvent(message.event.data);
      }
    };
  }

  function handleEvent(event) {
    if (event.scoreboard !== undefined) {
      const { team1: t1, team2: t2 } = event.scoreboard.config;
      setTeam1({ ...t1 });
      setTeam2({ ...t2 });
    }
  }

  function toggleFullscreen() {
    if (!document.fullscreenElement) {
      document.documentElement.requestFullscreen();
    } else {
      document.exitFullscreen();
    }
  }

  onMount(() => {
    document.body.addEventListener("click", toggleFullscreen);
    connect();
  });

  onCleanup(() => {
    document.body.removeEventListener("click", toggleFullscreen);
    if (ws) ws.close();
  });

  return (
    <div class="flex">
      <TeamColumn team={team1} />
      <TeamColumn team={team2} />
    </div>
  );
}

render(() => <App />, document.getElementById("app"));
