import { scoreboardWebsocketPort } from "./config.mjs";

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
    `ws://${window.location.hostname}:${scoreboardWebsocketPort}`,
  );
  socket.onopen = () => {
    socket.send(JSON.stringify({ requestSync: {} }));
  };
  socket.onclose = () => {
    setTimeout(connect, 2000);
  };
  socket.onmessage = (e) => {
    try {
      const message = JSON.parse(e.data);
      if (message.updates !== undefined) {
        updateTeam(1, msg.updates.team1);
        updateTeam(2, msg.updates.team2);
      }
    } catch (err) {
      console.error(err);
    }
  };
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
