#if DEBUG
import Foundation
/// Simulator-only test signal; no provider account, microphone or remote media.
enum ApplePlaybackSmoke {
    static let script = """
    (() => {
      let tries = 0;
      const wait = setInterval(() => {
        if (!window.__mineradioApplePlaybackReady) { if (++tries > 600) clearInterval(wait); return; }
        clearInterval(wait);
        const button = document.createElement('button');
        button.textContent = '播放测试音';
        button.style.cssText = 'position:fixed;top:80px;left:20px;z-index:2147483647;min-width:160px;min-height:48px;background:white;color:black';
        const status = document.createElement('p');
        status.style.cssText = 'position:fixed;top:140px;left:20px;z-index:2147483647;background:white;color:black';
        const report = result => window.webkit.messageHandlers.appleAudioProbe.postMessage(result).catch(() => {});
        button.onclick = async () => {
          let phase = 'wav';
          try {
            const count = 22050, bytes = new Uint8Array(44 + count * 2), v = new DataView(bytes.buffer);
            const text = (at, value) => { for (let i=0;i<value.length;i++) bytes[at+i]=value.charCodeAt(i); };
            text(0,'RIFF'); v.setUint32(4,36+count*2,true); text(8,'WAVE'); text(12,'fmt ');
            v.setUint32(16,16,true); v.setUint16(20,1,true); v.setUint16(22,1,true);
            v.setUint32(24,22050,true); v.setUint32(28,44100,true); v.setUint16(32,2,true); v.setUint16(34,16,true);
            text(36,'data'); v.setUint32(40,count*2,true);
            for(let i=0;i<count;i++) v.setInt16(44+i*2, Math.sin(i*2*Math.PI*440/22050)*12000,true);
            const url = URL.createObjectURL(new Blob([bytes], {type:'audio/wav'}));
            if (!audio) { audio = new Audio(); audio.crossOrigin = 'anonymous'; }
            phase = 'source'; audio.src = url; audio.loop = true;
            phase = 'graph'; initAudio(); phase = 'play'; await audio.play();
            setTimeout(() => {
              const samples = new Uint8Array(analyser.fftSize); analyser.getByteTimeDomainData(samples);
              const signal = samples.some(value => Math.abs(value-128)>3);
              report({state:audioCtx.state,mediaTime:audio.currentTime,signal});
              status.textContent = audioCtx.state === 'running' && audio.currentTime > 0.05 && signal ? '音频链路通过' : '音频链路失败';
              audio.pause(); URL.revokeObjectURL(url);
            }, 700);
          } catch(error) { report({error:phase + ':' + error.name + ':' + error.message}); status.textContent = '音频链路失败：' + error.name; }
        };
        document.body.append(button,status);
        if (window.__mineradioAppleSetAuthPresentation) window.__mineradioAppleSetAuthPresentation(true);
      }, 50);
    })();
    """
}
#endif
