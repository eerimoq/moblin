import { addOnClick, websocketUrl } from "./utils.mjs";

let ws = null;

function toggleFullscreen() {
  if (!document.fullscreenElement) {
    document.documentElement.requestFullscreen();
  } else {
    document.exitFullscreen();
  }
}

function connect() {
  ws = new WebSocket(websocketUrl());
  ws.onclose = () => {
    setTimeout(connect, 3000);
  };
  ws.onmessage = (e) => {
    const message = JSON.parse(e.data);
    if (message.event !== undefined) {
      handleEvent(message.event.data);
    }
  };
}

function handleEvent(event) {
  if (event.scoreboard !== undefined) {
    handleEventScoreboard(event.scoreboard);
  }
}

function handleEventScoreboard(scoreboard) {
  updateTeam(1, scoreboard.config.team1);
  updateTeam(2, scoreboard.config.team2);
}

function updateTeam(teamNumber, team) {
  const column = document.getElementById(`t${teamNumber}-column`);
  const bar = document.getElementById(`t${teamNumber}-bar`);
  const score = document.getElementById(`t${teamNumber}-set-score`);
  const name = document.getElementById(`t${teamNumber}-name`);
  const match = document.getElementById(`t${teamNumber}-match`);
  const serveIcon = document.getElementById(`t${teamNumber}-serve-icon`);

  column.style.backgroundColor = team.bgColor;
  bar.style.backgroundColor = team.bgColor;
  score.style.color = team.textColor;
  name.style.color = team.textColor;
  match.style.color = team.textColor;

  // Map new modular variables
  score.innerText = team.primaryScore;
  name.innerText = team.name;
  match.innerText = team.secondaryScore;

  if (team.possession) {
    serveIcon.classList.remove("hidden");
  } else {
    serveIcon.classList.add("hidden");
  }
}

window.addEventListener("DOMContentLoaded", async () => {
  addOnClick("body", toggleFullscreen);
  connect();
});
