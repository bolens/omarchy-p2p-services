(() => {
  const root = document.documentElement;
  const select = document.querySelector("[data-theme-select]");
  const themeColor = document.querySelector('meta[name="theme-color"]');
  if (!select) return;
  const themes = Array.from(select.options, option => option.value);
  const fallback = root.dataset.defaultTheme || "p2p";
  if (!themes.includes(root.dataset.theme)) root.dataset.theme = fallback;
  select.value = root.dataset.theme;
  const sync = () => { themeColor.content = getComputedStyle(root).getPropertyValue("--deep").trim(); };
  sync();
  select.addEventListener("change", () => {
    root.dataset.theme = select.value;
    try { localStorage.setItem(root.dataset.themeStorage, select.value); } catch {}
    sync();
  });
})();
