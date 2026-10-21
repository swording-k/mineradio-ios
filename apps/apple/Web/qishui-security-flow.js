/* Apple presentation lifecycle around the unchanged official Passport UI. */
(() => {
  window.__qishuiAppleSecondVerify = async (decision, options) => {
    let timer;
    window.__qishuiSecurityActive = true;
    try {
      const cancelled = new Promise(resolve => {
        window.__qishuiAppleCancel = () => {
          if (typeof window.__qishuiCancelSecondVerify === 'function') window.__qishuiCancelSecondVerify();
          resolve({status: false});
        };
        timer = setTimeout(window.__qishuiAppleCancel, 120000);
      });
      return await Promise.race([
        Promise.resolve().then(() => window.__qishuiSecondVerify(decision, options)),
        cancelled,
      ]);
    } finally {
      clearTimeout(timer);
      window.__qishuiAppleCancel = null;
      window.__qishuiSecurityActive = false;
    }
  };
})();
