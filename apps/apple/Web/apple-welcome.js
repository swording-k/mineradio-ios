// First-run entry for the bundled Apple client. Joined listeners and the shared
// unlock request keep accounts, reset and the legacy welcome phrase in sync.
(function installAppleWelcome() {
  var hero = document.querySelector('#empty-home .home-hero');
  var gate = document.getElementById('login-easter-egg-gate');
  var modal = document.getElementById('login-modal');
  if (!hero || !gate || !modal || document.getElementById('apple-welcome-home')) return;

  function element(tag, text, className) {
    var e = document.createElement(tag);
    if (text) e.textContent = text;
    if (className) e.className = className;
    return e;
  }
  function makeButton(text, action, secondary) {
    var b = element('button', text, secondary ? 'mr-welcome-secondary' : 'mr-welcome-primary');
    b.type = 'button';
    b.onclick = action;
    return b;
  }
  var welcome = element('section', '', 'mr-welcome'); welcome.id = 'apple-welcome-home';
  welcome.setAttribute('aria-label', '开始使用 Mineradio');
  welcome.appendChild(element('small', 'MINERADIO'));
  welcome.appendChild(element('h2', '播放你的第一首歌'));
  welcome.appendChild(element('p', '连接自己的歌单，或从这台设备选一首歌。'));
  welcome.appendChild(makeButton('连接音乐平台', function () { showLoginModal(); }));
  welcome.appendChild(makeButton('导入本地音乐', function () { triggerUploadInput('audio'); }, true));
  hero.appendChild(welcome);

  var panel = element('section', '', 'mr-welcome');
  panel.id = 'apple-welcome-gate';
  panel.appendChild(element('small', 'MINERADIO'));
  panel.appendChild(element('h2', '世界和平'));
  panel.appendChild(element('p', '这是 Mineradio 的欢迎口令。轻点下方，就能选择你的音乐平台。'));
  var submit = makeButton('用「世界和平」进入', enter);
  var error = element('div'); error.setAttribute('role', 'status');
  panel.appendChild(submit); panel.appendChild(error); gate.appendChild(panel);

  function sync() {
    var fresh = loginEasterEggState.ready && !loginEasterEggState.unlocked && !hasAnyPlatformLogin();
    hero.classList.toggle('mr-first-use', fresh);
    welcome.hidden = !fresh;
  }
  // A throttled first animation frame must not leave the visible welcome card
  // inside a click-through wallpaper. Keep the original splash and returning flow.
  if (typeof finishSplashReveal === 'function') {
    var finish = finishSplashReveal;
    finishSplashReveal = function () {
      var result = finish.apply(this, arguments);
      if (!hasAnyPlatformLogin() && !loginEasterEggState.unlocked && shouldShowEmptyHome())
        updateEmptyHomeVisibility();
      return result;
    };
  }
  var render = renderUserBtn;
  renderUserBtn = function () { var result = render.apply(this, arguments); sync(); return result; };
  var reset = resetLoginEasterEggUiForReplay;
  resetLoginEasterEggUiForReplay = function () { var result = reset.apply(this, arguments); sync(); return result; };

  // The shared desktop gate focuses the hidden eye after a delay. On touch the
  // single visible button owns focus; no private click counter or second store.
  prepareLoginEasterEggGate = async function () {
    var unlocked = await ensureLoginEasterEggStatus(false);
    setLoginEasterEggMode(!unlocked);
    error.textContent = '';
    sync();
    if (!unlocked && modal.classList.contains('show')) submit.focus({preventScroll:true});
    return unlocked;
  };
  async function enter() {
    if (submit.disabled) return;
    submit.disabled = true;
    error.textContent = '';
    try {
      var res = await requestLoginEasterEggUnlock('世界和平');
      if (!res || !res.ok || !res.unlocked || !(await ensureLoginEasterEggStatus(true))) {
        error.textContent = '欢迎口令未能保存，请重试。';
        return;
      }
      setLoginEasterEggMode(false); sync();
      if (modal.classList.contains('show')) {
        resumeLoginModalAfterGate();
        var first = document.querySelector('#login-platform-tabs button');
        if (first) first.focus({preventScroll:true});
      }
    } catch (_) { error.textContent = '连接未完成，请重试。'; }
    finally { submit.disabled = false; }
  }
  var style = element('style');
  style.textContent = `
    body.apple-client.empty-home-active #empty-home:has(.mr-first-use) {transition:none!important}
    #apple-welcome-home[hidden], .home-hero.mr-first-use > .daily-review-card {display:none!important}
    .mr-welcome {box-sizing:border-box; position:relative; z-index:2; width:100%; display:flex; flex-direction:column;
      align-items:flex-start; justify-content:center; gap:10px; padding:clamp(16px,4vw,40px); color:white; text-align:start}
    #apple-welcome-home {min-height:100%; background:linear-gradient(130deg,#172226ef,#121318e8)}
    .mr-welcome h2,.mr-welcome p {margin:0}
    .mr-welcome h2 {font-size:clamp(21px,4vw,34px); line-height:1.2}
    .mr-welcome small {font-size:10px; font-weight:700; letter-spacing:.22em; color:#b8ccc4}
    .mr-welcome p {font-size:14px; line-height:1.5; color:#d6d8da}
    .mr-welcome button {font:inherit; font-size:15px; font-weight:600; min-height:44px; padding:8px 16px;
      border-radius:14px; border:1px solid transparent; cursor:pointer}
    .mr-welcome-primary {background:#edfff6; color:#162a22}
    .mr-welcome-secondary {background:transparent; color:#eff4f2; border-color:#ffffff40!important}
    #login-modal.login-easter-egg-locked #login-easter-egg-gate > :not(#apple-welcome-gate) {display:none!important}
    #login-modal.login-easter-egg-locked #login-easter-egg-gate {min-height:0!important; padding:0!important; display:block!important}
    #login-modal.login-easter-egg-locked .dual-login-modal {min-height:0!important; max-height:calc(100dvh - env(safe-area-inset-top) - env(safe-area-inset-bottom) - 20px)!important; overflow-y:auto!important}
    #apple-welcome-gate {width:min(100%,480px); margin:auto}
    #apple-welcome-gate [role=status]:empty {display:none}
    @media (max-width:760px) and (orientation:portrait) {
      #empty-home .empty-home-shell:has(.mr-first-use) {display:flex!important;flex-direction:column;min-height:0;overflow-y:auto!important}
      #empty-home .empty-home-shell:has(.mr-first-use) > :not(.home-hero) {display:none!important}
      #empty-home .home-hero.mr-first-use {contain:none!important;min-height:0!important;height:auto!important}
    }
    @media (max-width:760px) and (orientation:portrait) { #apple-welcome-home {min-height:0} }
    @media (max-height:450px) {
      .mr-welcome {gap:5px; padding:10px 14px}
      #empty-home .home-hero.mr-first-use {overflow:auto!important}
    }
  `;
  document.head.appendChild(style);
  sync();
  ensureLoginEasterEggStatus(false).then(sync);
})();
