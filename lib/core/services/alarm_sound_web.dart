// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

void playAlarmAudio() {
  try {
    js.context.callMethod('eval', [r'''
      (function() {
        try {
          if (!window._medmateAudioCtx) {
            window._medmateAudioCtx = new (window.AudioContext || window.webkitAudioContext)();
          }
          var ctx = window._medmateAudioCtx;
          if (ctx.state === 'suspended') {
            ctx.resume();
          }
          window._medmateAlarmPlaying = true;
          
          function playTone(freq, duration, delay) {
            setTimeout(function() {
              if (!window._medmateAlarmPlaying) return;
              var osc = ctx.createOscillator();
              var gain = ctx.createGain();
              osc.type = 'sine';
              osc.frequency.setValueAtTime(freq, ctx.currentTime);
              gain.gain.setValueAtTime(0.22, ctx.currentTime);
              gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + duration);
              osc.connect(gain);
              gain.connect(ctx.destination);
              osc.start();
              osc.stop(ctx.currentTime + duration);
            }, delay);
          }
          
          function loop() {
            if (!window._medmateAlarmPlaying) return;
            playTone(880, 0.18, 0);
            playTone(1108.73, 0.18, 140);
            playTone(1318.51, 0.18, 280);
            playTone(1760, 0.32, 420);
            setTimeout(function() {
              if (window._medmateAlarmPlaying) loop();
            }, 1000);
          }
          loop();
        } catch(e) {}
      })();
    ''']);
  } catch (_) {}
}

void stopAlarmAudio() {
  try {
    js.context.callMethod('eval', [r'''
      window._medmateAlarmPlaying = false;
    ''']);
  } catch (_) {}
}
