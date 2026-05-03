import { websocketPort } from "./config.mjs";

export function getTableBodyNoHead(id) {
  let table = document.getElementById(id);
  while (table.rows.length > 0) {
    table.deleteRow(-1);
  }
  return table.tBodies[0];
}

export function appendToRow(row, value, className) {
  let cell = row.insertCell(-1);
  cell.innerHTML = value;
  if (className) {
    cell.className = className;
  }
}

export function addOnChange(elementId, func) {
  document.getElementById(elementId).addEventListener("change", func);
}

export function addOnClick(elementId, func) {
  document.getElementById(elementId).addEventListener("click", func);
}

export function addOnBlur(elementId, func) {
  document.getElementById(elementId).addEventListener("blur", func);
}

export function websocketUrl() {
  return `ws://${window.location.hostname}:${websocketPort}`;
}

let confirmComplete = null;
let confirmResult = false;

export async function confirm(message) {
  document.getElementById("confirm-message").textContent = message;
  const dialog = document.getElementById("confirm");
  dialog.showModal();
  await new Promise((resolve) => {
    confirmComplete = (result) => {
      confirmResult = result;
      resolve();
    };
  });
  dialog.close();
  return confirmResult;
}

export function confirmOk() {
  confirmComplete(true);
}

export function confirmCancel() {
  confirmComplete(false);
}
