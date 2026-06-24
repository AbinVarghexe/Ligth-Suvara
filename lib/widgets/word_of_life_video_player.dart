import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:sundayschool_app/providers/word_of_life_provider.dart';

class WordOfLifeVideoPlayer extends StatefulWidget {
  final WordOfLifeEntry entry;
  const WordOfLifeVideoPlayer({super.key, required this.entry});

  @override
  State<WordOfLifeVideoPlayer> createState() => _WordOfLifeVideoPlayerState();
}

class _WordOfLifeVideoPlayerState extends State<WordOfLifeVideoPlayer> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    final videoUrl = widget.entry.resolvedVideoUrl ?? '';
    debugPrint('WOL Video URL: $videoUrl');
    final isYoutube = widget.entry.isYoutubeVideo;
    final ytId = widget.entry.youtubeVideoId;
    final posterUrl = widget.entry.imageUrl ?? '';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (progress > 90) {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
              }
            }
          },
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
              });
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint("WOL Video WebView Error: ${error.description}, code: ${error.errorCode}");
          },
        ),
      );

    if (_controller.platform is AndroidWebViewController) {
      (_controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    if (isYoutube && ytId != null) {
      final embedUrl = 'https://www.youtube.com/embed/$ytId?autoplay=1&mute=0&rel=0&playsinline=1';
      _controller.loadRequest(Uri.parse(embedUrl));
    } else if (videoUrl.isNotEmpty) {
      final html = '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <style>
          body, html {
            margin: 0; padding: 0; width: 100%; height: 100%; overflow: hidden; background: #000;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            -webkit-user-select: none; user-select: none;
          }
          .player-container {
            position: relative; width: 100%; height: 100%; display: flex; justify-content: center; align-items: center;
          }
          video {
            width: 100%; height: 100%; object-fit: contain;
          }
          /* Controls Container */
          .controls {
            position: absolute; bottom: 0; left: 0; right: 0;
            background: linear-gradient(to top, rgba(0,0,0,0.85) 0%, rgba(0,0,0,0.5) 60%, transparent 100%);
            padding: 20px 16px 12px 16px;
            display: flex; flex-direction: column; gap: 8px;
            opacity: 0; transition: opacity 0.25s ease-in-out;
            z-index: 10;
          }
          .player-container.show-controls .controls,
          .player-container:hover .controls {
            opacity: 1;
          }
          .row {
            display: flex; align-items: center; justify-content: space-between; gap: 12px;
          }
          .left-controls, .right-controls {
            display: flex; align-items: center; gap: 14px;
          }
          /* Icon Buttons */
          .btn {
            background: none; border: none; outline: none; padding: 4px; cursor: pointer;
            color: #fff; display: flex; align-items: center; justify-content: center;
            transition: color 0.15s, transform 0.1s;
          }
          .btn:active {
            transform: scale(0.9);
          }
          .btn svg {
            width: 18px; height: 18px; fill: currentColor;
          }
          .btn.play-btn svg {
            width: 20px; height: 20px;
          }
          /* Seek Slider */
          .slider-container {
            flex: 1; display: flex; align-items: center; position: relative;
          }
          .slider {
            -webkit-appearance: none; width: 100%; height: 4px; background: rgba(255, 255, 255, 0.25);
            border-radius: 2px; outline: none; cursor: pointer; margin: 0;
          }
          .slider::-webkit-slider-thumb {
            -webkit-appearance: none; width: 12px; height: 12px; border-radius: 50%;
            background: #0d9488; cursor: pointer; box-shadow: 0 1px 4px rgba(0,0,0,0.4);
            transition: transform 0.1s;
          }
          .slider::-webkit-slider-thumb:hover {
            transform: scale(1.2);
          }
          /* Progress Track fill */
          .progress-fill {
            position: absolute; left: 0; top: 50%; height: 4px; transform: translateY(-50%);
            background: #0d9488; border-radius: 2px; pointer-events: none; width: 0%;
          }
          /* Time & Labels */
          .time {
            color: rgba(255,255,255,0.9); font-size: 11px; font-weight: 500; font-variant-numeric: tabular-nums;
          }
          /* Big Play Button Overlay */
          .big-play {
            position: absolute; width: 56px; height: 56px; border-radius: 50%;
            background: rgba(13, 148, 136, 0.9); color: #fff;
            display: flex; align-items: center; justify-content: center;
            border: none; cursor: pointer; transition: all 0.2s ease-in-out;
            box-shadow: 0 4px 14px rgba(13, 148, 136, 0.4);
            z-index: 5;
          }
          .big-play:active {
            transform: scale(0.9);
          }
          .big-play svg {
            width: 24px; height: 24px; fill: currentColor; margin-left: 2px;
          }
          .big-play.hidden {
            opacity: 0; pointer-events: none; transform: scale(0.7);
          }
        </style>
      </head>
      <body>
        <div class="player-container" id="container">
          <video id="video" playsinline preload="auto" poster="$posterUrl">
            <source src="$videoUrl" type="video/mp4">
          </video>
          
          <!-- Big Play Overlay -->
          <button class="big-play" id="bigPlayBtn">
            <svg viewBox="0 0 24 24"><path d="M8 5v14l11-7z"/></svg>
          </button>

          <!-- Bottom Controls -->
          <div class="controls">
            <!-- Progress Bar Row -->
            <div class="row">
              <div class="slider-container">
                <div class="progress-fill" id="progressFill"></div>
                <input type="range" class="slider" id="seekSlider" min="0" max="100" value="0">
              </div>
            </div>
            <!-- Buttons & Time Row -->
            <div class="row">
              <div class="left-controls">
                <button class="btn play-btn" id="playBtn">
                  <svg viewBox="0 0 24 24" id="playIcon"><path d="M8 5v14l11-7z"/></svg>
                  <svg viewBox="0 0 24 24" id="pauseIcon" style="display:none;"><path d="M6 19h4V5H6v14zm8-14v14h4V5h-4z"/></svg>
                </button>
                <div class="time">
                  <span id="currentTime">0:00</span> / <span id="duration">0:00</span>
                </div>
              </div>
              <div class="right-controls">
                <button class="btn" id="muteBtn">
                  <svg viewBox="0 0 24 24" id="volIcon"><path d="M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77z"/></svg>
                  <svg viewBox="0 0 24 24" id="muteIcon" style="display:none;"><path d="M16.5 12c0-1.77-1.02-3.29-2.5-4.03v2.21l2.45 2.45c.03-.21.05-.42.05-.63zm2.5 0c0 .94-.2 1.82-.54 2.64l1.51 1.51C20.63 14.91 21 13.5 21 12c0-4.28-2.99-7.86-7-8.77v2.06c2.89.86 5 3.54 5 6.71zM4.27 3L3 4.27 7.73 9H3v6h4l5 5v-6.73l4.25 4.25c-.67.52-1.42.93-2.25 1.18v2.06c1.38-.31 2.63-.95 3.69-1.81L19.73 21 21 19.73l-9-9L4.27 3zM12 4L9.91 6.09 12 8.18V4z"/></svg>
                </button>
                <button class="btn" id="fsBtn">
                  <svg viewBox="0 0 24 24"><path d="M7 14H5v5h5v-2H7v-3zm-2-4h2V7h3V5H5v5zm12 7h-3v2h5v-5h-2v3zM14 5v2h3v3h2V5h-5z"/></svg>
                </button>
              </div>
            </div>
          </div>
        </div>

        <script>
          const container = document.getElementById('container');
          const video = document.getElementById('video');
          const playBtn = document.getElementById('playBtn');
          const bigPlayBtn = document.getElementById('bigPlayBtn');
          const playIcon = document.getElementById('playIcon');
          const pauseIcon = document.getElementById('pauseIcon');
          const muteBtn = document.getElementById('muteBtn');
          const volIcon = document.getElementById('volIcon');
          const muteIcon = document.getElementById('muteIcon');
          const seekSlider = document.getElementById('seekSlider');
          const progressFill = document.getElementById('progressFill');
          const currentTimeEl = document.getElementById('currentTime');
          const durationEl = document.getElementById('duration');
          const fsBtn = document.getElementById('fsBtn');

          let controlsTimeout;

          function formatTime(secs) {
            if (isNaN(secs)) return '0:00';
            const m = Math.floor(secs / 60);
            const s = Math.floor(secs % 60).toString().padStart(2, '0');
            return m + ':' + s;
          }

          function togglePlay() {
            if (video.paused) {
              video.play().catch(err => console.log(err));
            } else {
              video.pause();
            }
          }

          function updatePlayState() {
            if (video.paused) {
              playIcon.style.display = 'block';
              pauseIcon.style.display = 'none';
              bigPlayBtn.classList.remove('hidden');
            } else {
              playIcon.style.display = 'none';
              pauseIcon.style.display = 'block';
              bigPlayBtn.classList.add('hidden');
            }
          }

          video.addEventListener('play', updatePlayState);
          video.addEventListener('pause', updatePlayState);
          video.addEventListener('click', togglePlay);
          playBtn.addEventListener('click', togglePlay);
          bigPlayBtn.addEventListener('click', togglePlay);

          // Time & Progress update
          video.addEventListener('timeupdate', () => {
            if (!video.duration) return;
            const pct = (video.currentTime / video.duration) * 100;
            seekSlider.value = pct;
            progressFill.style.width = pct + '%';
            currentTimeEl.textContent = formatTime(video.currentTime);
          });

          video.addEventListener('loadedmetadata', () => {
            durationEl.textContent = formatTime(video.duration);
            // Force first frame rendering by seeking slightly
            if (video.currentTime === 0) {
              video.currentTime = 0.1;
            }
          });

          video.addEventListener('loadeddata', () => {
            if (video.currentTime === 0) {
              video.currentTime = 0.1;
            }
          });

          // Seek input
          seekSlider.addEventListener('input', () => {
            const time = (seekSlider.value / 100) * video.duration;
            video.currentTime = time;
            progressFill.style.width = seekSlider.value + '%';
          });

          // Mute/Unmute
          muteBtn.addEventListener('click', () => {
            video.muted = !video.muted;
            if (video.muted) {
              volIcon.style.display = 'none';
              muteIcon.style.display = 'block';
            } else {
              volIcon.style.display = 'block';
              muteIcon.style.display = 'none';
            }
          });

          // Fullscreen
          fsBtn.addEventListener('click', () => {
            if (!document.fullscreenElement) {
              container.requestFullscreen().catch(err => {
                if (video.requestFullscreen) video.requestFullscreen();
              });
            } else {
              document.exitFullscreen();
            }
          });

          // Hide controls on inactivity
          function resetControlsTimer() {
            container.classList.add('show-controls');
            clearTimeout(controlsTimeout);
            controlsTimeout = setTimeout(() => {
              if (!video.paused) {
                container.classList.remove('show-controls');
              }
            }, 2500);
          }

          container.addEventListener('mousemove', resetControlsTimer);
          container.addEventListener('touchstart', resetControlsTimer);
          video.addEventListener('play', resetControlsTimer);
        </script>
      </body>
      </html>
      ''';
      _controller.loadHtmlString(
        html,
        baseUrl: 'https://firebasestorage.googleapis.com',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // WebView Widget
          WebViewWidget.fromPlatformCreationParams(
            params: AndroidWebViewWidgetCreationParams(
              controller: _controller.platform,
              displayWithHybridComposition: true,
            ),
          ),
          // Loading spinner
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF0D9488),
                strokeWidth: 3,
              ),
            ),
        ],
      ),
    );
  }
}
