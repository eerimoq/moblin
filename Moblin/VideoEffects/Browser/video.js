class MoblinCanvasDrawer {
  constructor(video) {
    this.video = video;
    this.canvas = document.createElement("canvas");
    this.canvasContext = this.canvas.getContext("2d");
    this.video.requestVideoFrameCallback(this.handleVideoFrame);
    this.isPlaying = false;
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
    this.timer = null;
    this.setPlaying(false);
    moblinideoPlayingUpdated();
  };

  handleTimer = () => {
    if (this.video?.paused) {
      this.canvas.width = 0;
      this.canvas.height = 0;
      this.setPlaying(false);
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

  handleVideoFrame = () => {
    if (this.canvasContext === null) {
      return;
    }
    this.positionCanvas();
    this.canvasContext.drawImage(
      this.video,
      0,
      0,
      this.canvas.width,
      this.canvas.height,
    );
    this.setPlaying(true);
    this.video.requestVideoFrameCallback(this.handleVideoFrame);
  };

  setPlaying = (playing) => {
    if (this.isPlaying === playing) {
      return;
    }
    this.isPlaying = playing;
    moblinVideoPlayingUpdated();
  };
}

function moblinIsAnyVideoPlaying() {
  for (const moblinCanvasDrawer of moblinCanvasDrawers.values()) {
    if (moblinCanvasDrawer.isPlaying) {
      return true;
    }
  }
  return false;
}

let moblinPublishedVideoPlaying = false;

function moblinVideoPlayingUpdated() {
  const videoPlaying = moblinIsAnyVideoPlaying();
  if (videoPlaying === moblinPublishedVideoPlaying) {
    return;
  }
  moblinPublishedVideoPlaying = videoPlaying;
  try {
    moblin.publish({
      videoPlaying: { value: videoPlaying },
    });
  } catch {}
}

function moblinUpdateVideosPlaysInline() {
  document.querySelectorAll("video").forEach((video) => {
    video.setAttribute("playsinline", "");
  });
}

let moblinCanvasDrawers = new Map();

function moblinUpdateCanvasDrawers() {
  const videos = [...document.querySelectorAll("video")];
  videos.forEach((video) => {
    if (moblinCanvasDrawers.get(video) === undefined) {
      moblinCanvasDrawers.set(video, new MoblinCanvasDrawer(video));
    }
  });
  for (const [video, canvasDrawer] of moblinCanvasDrawers.entries()) {
    if (!videos.includes(video)) {
      canvasDrawer.tearDown();
      moblinCanvasDrawers.delete(video);
    }
  }
}

function moblinUpdateVideosConfigured() {
  moblinUpdateVideosPlaysInline();
  moblinUpdateCanvasDrawers();
}

const moblinObserver = new MutationObserver(() => {
  moblinUpdateVideosConfigured();
});
moblinObserver.observe(document, { childList: true, subtree: true });

document.addEventListener("DOMContentLoaded", () => {
  moblinUpdateVideosConfigured();
});
