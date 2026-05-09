// Confirm dialog state - shared across the page
let confirmResolve = null;

export async function confirm(message) {
  return new Promise((resolve) => {
    confirmResolve = resolve;
    const dialog = document.getElementById("confirm");
    const msgEl = document.getElementById("confirm-message");
    if (msgEl) msgEl.textContent = message;
    if (dialog) dialog.showModal();
  });
}

export function confirmOk() {
  const dialog = document.getElementById("confirm");
  if (dialog) dialog.close();
  if (confirmResolve) {
    confirmResolve(true);
    confirmResolve = null;
  }
}

export function confirmCancel() {
  const dialog = document.getElementById("confirm");
  if (dialog) dialog.close();
  if (confirmResolve) {
    confirmResolve(false);
    confirmResolve = null;
  }
}
