import { websocketPort } from "./config.mjs";

function toggleFullscreen() {
  if (!document.fullscreenElement) {
    document.documentElement.requestFullscreen();
  } else {
    if (document.exitFullscreen) {
      document.exitFullscreen();
    }
  }
}

function connect() {
  const socket = new WebSocket(
    `ws://${window.location.hostname}:${websocketPort}`,
  );
  socket.onclose = () => {
    setTimeout(connect, 3000);
  };
  socket.onmessage = (e) => {
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

function updateTeam(num, data) {
  const col = document.getElementById("t" + num + "-column");
  const bar = document.getElementById("t" + num + "-bar");
  const score = document.getElementById("t" + num + "-set-score");
  const name = document.getElementById("t" + num + "-name");
  const match = document.getElementById("t" + num + "-match");
  const icon = document.getElementById("t" + num + "-serve-icon");

  col.style.backgroundColor = data.bgColor;
  bar.style.backgroundColor = data.bgColor;
  score.style.color = data.textColor;
  name.style.color = data.textColor;
  match.style.color = data.textColor;

  // Map new modular variables
  score.innerText = data.primaryScore;
  name.innerText = data.name;
  match.innerText = data.secondaryScore;

  if (data.possession) {
    icon.classList.remove("hidden");
  } else {
    icon.classList.add("hidden");
  }
}
connect();

window.toggleFullscreen = toggleFullscreen;
