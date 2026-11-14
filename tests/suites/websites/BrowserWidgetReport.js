const browserWidgetReportName = document.currentScript.dataset.name;

function browserWidgetReport(status) {
  fetch(`/report/${browserWidgetReportName}/${encodeURIComponent(status)}`, { cache: "no-store" });
}

window.addEventListener("error", (event) => {
  browserWidgetReport(`error: ${event.message}`);
});

window.addEventListener("unhandledrejection", (event) => {
  browserWidgetReport(`error: ${event.reason}`);
});
