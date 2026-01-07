const secure = `${window.location.protocol == "https:" ? "s" : ""}`;
export const wsScheme = `ws${secure}`;
export const httpScheme = `http${secure}`;

export const relayStatus = {
  connecting: "Connecting...",
  connected: "Connected",
  kicked: "Kicked",
};

export const connectionStatus = {
  connectingToRelay: "Connecting to Relay...",
  connectingToAssistant: "Connecting to assistant on this computer...",
  assistantClosed: "Assistant connection closed",
  assistantError: "Assistant connection error",
  connected: "Connected",
  streamerClosed: "Streamer connection closed",
  streamerError: "Streamer connection error",
  rateLimitExceeded: "Rate limit exceeded",
};

function numberSuffix(value) {
  return value == 1 ? "" : "s";
}

export function timeAgoString(fromDate) {
  let now = new Date();
  let secondsAgo = parseInt((now.getTime() - fromDate.getTime()) / 1000);
  if (secondsAgo < 60) {
    return `${secondsAgo} second${numberSuffix(secondsAgo)} ago`;
  } else if (secondsAgo < 3600) {
    let minutesAgo = parseInt(secondsAgo / 60);
    return `${minutesAgo} minute${numberSuffix(minutesAgo)} ago`;
  } else if (secondsAgo < 86400) {
    let hoursAgo = parseInt(secondsAgo / 3600);
    return `${hoursAgo} hour${numberSuffix(hoursAgo)} ago`;
  } else {
    return fromDate.toDateString();
  }
}

export function bitrateToString(bitrate) {
  if (bitrate < 1000) {
    return `${bitrate} bps`;
  } else if (bitrate < 1000000) {
    let bitrateKbps = (bitrate / 1000).toFixed(1);
    return `${bitrateKbps} kbps`;
  } else {
    let bitrateMbps = (bitrate / 1000000).toFixed(1);
    return `${bitrateMbps} Mbps`;
  }
}

export function bytesToString(bytes) {
  if (bytes < 1000) {
    return `${bytes} B`;
  } else if (bytes < 1000000) {
    let bytesKb = (bytes / 1000).toFixed(1);
    return `${bytesKb} kB`;
  } else if (bytes < 1000000000) {
    let bytesMb = (bytes / 1000000).toFixed(1);
    return `${bytesMb} MB`;
  } else {
    let bytesGb = (bytes / 1000000000).toFixed(1);
    return `${bytesGb} GB`;
  }
}

export function getTableBody(id) {
  let table = document.getElementById(id);
  while (table.rows.length > 1) {
    table.deleteRow(-1);
  }
  return table.tBodies[0];
}

export function getTableBodyNoHead(id) {
  let table = document.getElementById(id);
  while (table.rows.length > 0) {
    table.deleteRow(-1);
  }
  return table.tBodies[0];
}

export function appendToRow(row, value) {
  let cell = row.insertCell(-1);
  cell.innerHTML = value;
}

function dec2hex(dec) {
  return dec.toString(16).padStart(2, "0");
}

export function randomString() {
  var arr = new Uint8Array((64 || 40) / 2);
  window.crypto.getRandomValues(arr);
  return Array.from(arr, dec2hex).join("");
}

function utf8Encode(text) {
  const encoder = new TextEncoder();
  return encoder.encode(text);
}

async function sha256Encode(data) {
  return await crypto.subtle.digest("SHA-256", data);
}

function base64Encode(data) {
  return btoa(String.fromCharCode(...new Uint8Array(data)));
}

export async function hashPassword(password, challenge, salt) {
  let concatenated = password + salt;
  let hash = await sha256Encode(utf8Encode(concatenated));
  concatenated = base64Encode(hash) + challenge;
  hash = await sha256Encode(utf8Encode(concatenated));
  return base64Encode(hash);
}

export function addOnClick(elementId, func) {
  document.getElementById(elementId).addEventListener("click", func);
}

export function addOnChange(elementId, func) {
  document.getElementById(elementId).addEventListener("change", func);
}
