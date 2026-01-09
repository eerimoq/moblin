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

export function addOnChange(elementId, func) {
  document.getElementById(elementId).addEventListener("change", func);
}
