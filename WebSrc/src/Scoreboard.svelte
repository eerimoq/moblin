<svelte:head>
  <title>Moblin Scoreboard Display</title>
  <link rel="stylesheet" href="css/app.css" />
  <link rel="stylesheet" href="css/common.css" />
  <link rel="stylesheet" href="css/scoreboard.css" />
</svelte:head>

<script>
  import { websocketUrl } from "./lib/websocket.js";

  let team1 = $state({ bgColor: "#000", textColor: "#fff", primaryScore: "0", secondaryScore: "0", name: "TEAM 1", possession: false });
  let team2 = $state({ bgColor: "#000", textColor: "#fff", primaryScore: "0", secondaryScore: "0", name: "TEAM 2", possession: false });

  function connect() {
    const ws = new WebSocket(websocketUrl());
    ws.onclose = () => setTimeout(connect, 3000);
    ws.onmessage = (e) => {
      const message = JSON.parse(e.data);
      if (message.event !== undefined) handleEvent(message.event.data);
    };
  }

  function handleEvent(event) {
    if (event.scoreboard !== undefined) handleEventScoreboard(event.scoreboard);
  }

  function handleEventScoreboard(scoreboard) {
    team1 = { ...team1, ...scoreboard.config.team1 };
    team2 = { ...team2, ...scoreboard.config.team2 };
  }

  function toggleFullscreen() {
    if (!document.fullscreenElement) {
      document.documentElement.requestFullscreen();
    } else {
      document.exitFullscreen();
    }
  }

  connect();
</script>

<!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
<div class="flex" onclick={toggleFullscreen} style="cursor:pointer">
  <div class="team-column" style="background-color:{team1.bgColor}">
    <div class="score-container">
      <div class="set-score" style="color:{team1.textColor}">{team1.primaryScore}</div>
    </div>
    <div class="info-bar" style="background-color:{team1.bgColor}">
      <div class="match-box" style="color:{team1.textColor}">{team1.secondaryScore}</div>
      <div class="team-name" style="color:{team1.textColor}">{team1.name}</div>
      <div class="serve-box">
        {#if team1.possession}
          <img src="/volleyball.png" class="serve-img" alt="" />
        {/if}
      </div>
    </div>
  </div>

  <div class="team-column" style="background-color:{team2.bgColor}">
    <div class="score-container">
      <div class="set-score" style="color:{team2.textColor}">{team2.primaryScore}</div>
    </div>
    <div class="info-bar" style="background-color:{team2.bgColor}">
      <div class="match-box" style="color:{team2.textColor}">{team2.secondaryScore}</div>
      <div class="team-name" style="color:{team2.textColor}">{team2.name}</div>
      <div class="serve-box">
        {#if team2.possession}
          <img src="/volleyball.png" class="serve-img" alt="" />
        {/if}
      </div>
    </div>
  </div>
</div>
