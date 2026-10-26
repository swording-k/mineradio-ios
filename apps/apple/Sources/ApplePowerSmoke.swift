#if DEBUG && targetEnvironment(simulator)
import Foundation
/// Measures the actual bundled scheduler in foreground WebKit, without accounts.
enum ApplePowerSmoke {
    static let script = """
    (() => {
      let tries=0;
      const wait=setInterval(() => {
        if (!window.__mineradioApplePower) { if(++tries>600) clearInterval(wait); return; }
        clearInterval(wait);
        document.body.classList.remove('splash-active','home-controls-locked');
        document.getElementById('splash').style.display='none';
        document.getElementById('empty-home').style.display='none';
        const status=document.createElement('p');
        status.style.cssText='position:fixed;top:150px;left:20px;z-index:2147483647;background:white;color:black';
        const start=document.createElement('button'); start.textContent='检查暂停调度';
        start.style.cssText='position:fixed;top:80px;left:20px;z-index:2147483647;min-height:44px;background:white;color:black';
        const wake=document.createElement('button'); wake.textContent='唤醒播放界面';
        wake.style.cssText='position:fixed;top:200px;left:20px;z-index:2147483647;min-height:44px;background:white;color:black';
        let frames=0, sampled=false;
        const originalAnimate=animate;
        animate=function(){ frames++; return originalAnimate.apply(this,arguments); };
        start.onclick=async()=>{
          if(audio)audio.pause(); playing=false; clearStageLyrics();
          window.__mineradioAppleSetAuthPresentation(false);
          status.textContent='等待暂停舞台稳定';
          const deadline=Date.now()+15000;
          while(mainLoopBackgroundDelayMs()!==500 && Date.now()<deadline) await new Promise(r=>setTimeout(r,250));
          const before=frames;
          await new Promise(r=>setTimeout(r,2200));
          const count=frames-before;
          sampled=mainLoopBackgroundDelayMs()===500 && count>=2 && count<=6;
          status.textContent=sampled?'暂停调度通过：'+count+' 次 / 2.2 秒':'暂停调度失败：'+mainLoopBackgroundDelayMs()+' / '+count;
        };
        wake.onclick=()=>{
          const active=sampled && !window.__mineradioApplePower.snapshot().idle && mainLoopBackgroundDelayMs()===0;
          status.textContent=active?'触控唤醒通过':'触控唤醒失败';
          window.__mineradioAppleSetAuthPresentation(true);
        };
        document.body.append(start,status,wake);
      },50);
    })();
    """
}
#endif
