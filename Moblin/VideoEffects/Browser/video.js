class MoblinVideoOnCanvasDrawer {
  constructor(video) {
    this.video = video;
    this.canvas = document.createElement("canvas");
    this.canvasContext = this.canvas.getContext("2d");
    this.video.requestVideoFrameCallback(this.handleVideoFrame);
    document.body.appendChild(this.canvas);
    this.timer = setInterval(() => {
      this.handleTimer();
    }, 100);
  }

  tearDown = () => {
    document.body.removeChild(this.canvas);
    this.video = null;
    this.canvas = null;
    this.canvasContext = null;
    clearInterval(this.timer);
    this.timer = null
  };

  handleTimer = () => {
    if (this.video?.paused) {
      this.canvas.width = 0;
      this.canvas.height = 0;
    }
  };

  positionCanvas = () => {
    const rect = this.video.getBoundingClientRect();
    this.canvas.width = this.video.videoWidth;
    this.canvas.height = this.video.videoHeight;
    this.canvas.style.position = "absolute";
    this.canvas.style.left = rect.left + window.scrollX + "px";
    this.canvas.style.top = rect.top + window.scrollY + "px";
    this.canvas.style.width = rect.width + "px";
    this.canvas.style.height = rect.height + "px";
    this.canvas.style.zIndex = -9999;
  };

  handleVideoFrame = (now, metadata) => {
    if (this.canvasContext === null) {
      return;
    }
    this.positionCanvas();
    this.canvasContext.drawImage(
      this.video,
      0,
      0,
      this.canvas.width,
      this.canvas.height
    );
    this.video.requestVideoFrameCallback(this.handleVideoFrame);
  };
}

function moblinUpdateVideosPlaysInline() {
  document.querySelectorAll("video").forEach((video) => {
    video.setAttribute("playsinline", "");
  });
}

let moblinVideoOnCanvasDrawers = new Map();

function moblinUpdateVideoOnCanvasDrawers() {
  const videos = [...document.querySelectorAll("video")];
  videos.forEach((video) => {
    if (moblinVideoOnCanvasDrawers.get(video) === undefined) {
      moblinVideoOnCanvasDrawers.set(
        video,
        new MoblinVideoOnCanvasDrawer(video)
      );
    }
  });
  for (const video of moblinVideoOnCanvasDrawers.keys()) {
    if (!videos.includes(video)) {
      moblinVideoOnCanvasDrawers.get(video).tearDown();
      moblinVideoOnCanvasDrawers.delete(video);
    }
  }
}

function moblinUpdateVideosConfigured() {
  moblinUpdateVideosPlaysInline();
  moblinUpdateVideoOnCanvasDrawers();
}

const moblinObserver = new MutationObserver((mutationList, observer) => {
  moblinUpdateVideosConfigured();
});
moblinObserver.observe(document, { childList: true, subtree: true });

document.addEventListener("DOMContentLoaded", (event) => {
  moblinUpdateVideosConfigured();
});
