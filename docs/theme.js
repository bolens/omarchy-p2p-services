(() => {
  const root = document.documentElement;
  const select = document.querySelector("[data-theme-select]");
  const themeColor = document.querySelector('meta[name="theme-color"]');
  if (!select) return;
  const darkTheme = root.dataset.defaultTheme || "p2p";
  const lightTheme = "github-light";
  const mediaQuery = query => typeof matchMedia === "function" ? matchMedia(query) : { matches: false };
  const darkQuery = mediaQuery("(prefers-color-scheme: dark)");
  const lightQuery = mediaQuery("(prefers-color-scheme: light)");
  let timer;
  const resolve = preference => {
    if (preference === "time") return new Date().getHours() >= 7 && new Date().getHours() < 19 ? lightTheme : darkTheme;
    if (preference === "system") {
      if (lightQuery.matches) return lightTheme;
      if (darkQuery.matches) return darkTheme;
      return darkTheme;
    }
    return preference;
  };
  const apply = preference => {
    root.dataset.themePreference = preference;
    root.dataset.theme = resolve(preference);
    select.value = preference;
    if (themeColor) themeColor.content = getComputedStyle(root).getPropertyValue("--deep").trim();
    clearInterval(timer);
    if (preference === "time") timer = setInterval(() => apply("time"), 60_000);
  };
  const available = Array.from(select.options, option => option.value);
  apply(available.includes(root.dataset.themePreference) ? root.dataset.themePreference : "system");
  select.addEventListener("change", () => {
    try { if (root.dataset.themeStorage) localStorage.setItem(root.dataset.themeStorage, select.value); } catch {}
    apply(select.value);
  });
  darkQuery.addEventListener?.("change", () => { if (root.dataset.themePreference === "system") apply("system"); });
  lightQuery.addEventListener?.("change", () => { if (root.dataset.themePreference === "system") apply("system"); });
})();
