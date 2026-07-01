const STORAGE_KEY = "streamory-config";
const POSTER_BASE = "https://artworks.thetvdb.com";
const STATUSES = {
  watchlist: "À voir",
  watching: "En cours",
  watched: "Vu"
};
const COUNTRY_LANGUAGE_CODES = {
  AD: "cat",
  AE: "ara",
  AF: "fas",
  AG: "eng",
  AI: "eng",
  AL: "sqi",
  AM: "hye",
  AO: "por",
  AR: "spa",
  AS: "eng",
  AT: "deu",
  AU: "eng",
  AW: "nld",
  AX: "swe",
  AZ: "aze",
  BA: "bos",
  BB: "eng",
  BD: "ben",
  BE: "nld",
  BF: "fra",
  BG: "bul",
  BH: "ara",
  BI: "fra",
  BJ: "fra",
  BL: "fra",
  BM: "eng",
  BN: "msa",
  BO: "spa",
  BQ: "nld",
  BR: "por",
  BS: "eng",
  BT: "dzo",
  BW: "eng",
  BY: "bel",
  BZ: "eng",
  CA: "eng",
  CD: "fra",
  CF: "fra",
  CG: "fra",
  CH: "deu",
  CI: "fra",
  CK: "eng",
  CL: "spa",
  CM: "fra",
  CN: "zho",
  CO: "spa",
  CR: "spa",
  CU: "spa",
  CV: "por",
  CW: "nld",
  CY: "ell",
  CZ: "ces",
  DE: "deu",
  DJ: "fra",
  DK: "dan",
  DM: "eng",
  DO: "spa",
  DZ: "ara",
  EC: "spa",
  EE: "est",
  EG: "ara",
  ER: "ara",
  ES: "spa",
  ET: "amh",
  FI: "fin",
  FJ: "eng",
  FK: "eng",
  FM: "eng",
  FO: "fao",
  FR: "fra",
  GA: "fra",
  GB: "eng",
  GD: "eng",
  GE: "kat",
  GF: "fra",
  GG: "eng",
  GH: "eng",
  GI: "eng",
  GL: "kal",
  GM: "eng",
  GN: "fra",
  GP: "fra",
  GQ: "spa",
  GR: "ell",
  GT: "spa",
  GU: "eng",
  GW: "por",
  GY: "eng",
  HK: "zho",
  HN: "spa",
  HR: "hrv",
  HT: "fra",
  HU: "hun",
  ID: "ind",
  IE: "eng",
  IL: "heb",
  IM: "eng",
  IN: "hin",
  IQ: "ara",
  IR: "fas",
  IS: "isl",
  IT: "ita",
  JE: "eng",
  JM: "eng",
  JO: "ara",
  JP: "jpn",
  KE: "eng",
  KG: "kir",
  KH: "khm",
  KI: "eng",
  KM: "ara",
  KN: "eng",
  KP: "kor",
  KR: "kor",
  KW: "ara",
  KY: "eng",
  KZ: "kaz",
  LA: "lao",
  LB: "ara",
  LC: "eng",
  LI: "deu",
  LK: "sin",
  LR: "eng",
  LS: "eng",
  LT: "lit",
  LU: "fra",
  LV: "lav",
  LY: "ara",
  MA: "ara",
  MC: "fra",
  MD: "ron",
  ME: "srp",
  MF: "fra",
  MG: "fra",
  MH: "eng",
  MK: "mkd",
  ML: "fra",
  MM: "mya",
  MN: "mon",
  MO: "zho",
  MP: "eng",
  MQ: "fra",
  MR: "ara",
  MS: "eng",
  MT: "mlt",
  MU: "eng",
  MV: "div",
  MW: "eng",
  MX: "spa",
  MY: "msa",
  MZ: "por",
  NA: "eng",
  NC: "fra",
  NE: "fra",
  NG: "eng",
  NI: "spa",
  NL: "nld",
  NO: "nor",
  NP: "nep",
  NR: "eng",
  NU: "eng",
  NZ: "eng",
  OM: "ara",
  PA: "spa",
  PE: "spa",
  PF: "fra",
  PG: "eng",
  PH: "eng",
  PK: "urd",
  PL: "pol",
  PM: "fra",
  PR: "spa",
  PS: "ara",
  PT: "por",
  PW: "eng",
  PY: "spa",
  QA: "ara",
  RE: "fra",
  RO: "ron",
  RS: "srp",
  RU: "rus",
  RW: "kin",
  SA: "ara",
  SB: "eng",
  SC: "fra",
  SD: "ara",
  SE: "swe",
  SG: "eng",
  SH: "eng",
  SI: "slv",
  SK: "slk",
  SL: "eng",
  SM: "ita",
  SN: "fra",
  SO: "som",
  SR: "nld",
  SS: "eng",
  ST: "por",
  SV: "spa",
  SX: "nld",
  SY: "ara",
  SZ: "eng",
  TC: "eng",
  TD: "fra",
  TG: "fra",
  TH: "tha",
  TJ: "tgk",
  TK: "eng",
  TL: "por",
  TM: "tuk",
  TN: "ara",
  TO: "eng",
  TR: "tur",
  TT: "eng",
  TV: "eng",
  TW: "zho",
  TZ: "swa",
  UA: "ukr",
  UG: "eng",
  US: "eng",
  UY: "spa",
  UZ: "uzb",
  VA: "ita",
  VC: "eng",
  VE: "spa",
  VG: "eng",
  VI: "eng",
  VN: "vie",
  VU: "bis",
  WF: "fra",
  WS: "eng",
  YE: "ara",
  YT: "fra",
  ZA: "eng",
  ZM: "eng",
  ZW: "eng"
};
const COUNTRY_CODES = [
  "AD", "AE", "AF", "AG", "AI", "AL", "AM", "AO", "AQ", "AR", "AS", "AT", "AU", "AW", "AX", "AZ",
  "BA", "BB", "BD", "BE", "BF", "BG", "BH", "BI", "BJ", "BL", "BM", "BN", "BO", "BQ", "BR", "BS",
  "BT", "BV", "BW", "BY", "BZ", "CA", "CC", "CD", "CF", "CG", "CH", "CI", "CK", "CL", "CM", "CN",
  "CO", "CR", "CU", "CV", "CW", "CX", "CY", "CZ", "DE", "DJ", "DK", "DM", "DO", "DZ", "EC", "EE",
  "EG", "EH", "ER", "ES", "ET", "FI", "FJ", "FK", "FM", "FO", "FR", "GA", "GB", "GD", "GE", "GF",
  "GG", "GH", "GI", "GL", "GM", "GN", "GP", "GQ", "GR", "GS", "GT", "GU", "GW", "GY", "HK", "HM",
  "HN", "HR", "HT", "HU", "ID", "IE", "IL", "IM", "IN", "IO", "IQ", "IR", "IS", "IT", "JE", "JM",
  "JO", "JP", "KE", "KG", "KH", "KI", "KM", "KN", "KP", "KR", "KW", "KY", "KZ", "LA", "LB", "LC",
  "LI", "LK", "LR", "LS", "LT", "LU", "LV", "LY", "MA", "MC", "MD", "ME", "MF", "MG", "MH", "MK",
  "ML", "MM", "MN", "MO", "MP", "MQ", "MR", "MS", "MT", "MU", "MV", "MW", "MX", "MY", "MZ", "NA",
  "NC", "NE", "NF", "NG", "NI", "NL", "NO", "NP", "NR", "NU", "NZ", "OM", "PA", "PE", "PF", "PG",
  "PH", "PK", "PL", "PM", "PN", "PR", "PS", "PT", "PW", "PY", "QA", "RE", "RO", "RS", "RU", "RW",
  "SA", "SB", "SC", "SD", "SE", "SG", "SH", "SI", "SJ", "SK", "SL", "SM", "SN", "SO", "SR", "SS",
  "ST", "SV", "SX", "SY", "SZ", "TC", "TD", "TF", "TG", "TH", "TJ", "TK", "TL", "TM", "TN", "TO",
  "TR", "TT", "TV", "TW", "TZ", "UA", "UG", "UM", "US", "UY", "UZ", "VA", "VC", "VE", "VG", "VI",
  "VN", "VU", "WF", "WS", "YE", "YT", "ZA", "ZM", "ZW"
];

const state = {
  client: null,
  session: null,
  statusFilter: "all",
  library: [],
  friendNotifications: [],
  config: loadConfig()
};

const els = {
  siteTitle: document.querySelector("#siteTitle"),
  authPanel: document.querySelector("#authPanel"),
  appControls: document.querySelector("#appControls"),
  libraryPanel: document.querySelector("#libraryPanel"),
  showLoginButton: document.querySelector("#showLoginButton"),
  showSignupButton: document.querySelector("#showSignupButton"),
  loginForm: document.querySelector("#loginForm"),
  signupForm: document.querySelector("#signupForm"),
  loginEmailInput: document.querySelector("#loginEmailInput"),
  loginPasswordInput: document.querySelector("#loginPasswordInput"),
  usernameInput: document.querySelector("#usernameInput"),
  signupEmailInput: document.querySelector("#signupEmailInput"),
  signupPasswordInput: document.querySelector("#signupPasswordInput"),
  confirmPasswordInput: document.querySelector("#confirmPasswordInput"),
  birthDateInput: document.querySelector("#birthDateInput"),
  countryInput: document.querySelector("#countryInput"),
  loginMessage: document.querySelector("#loginMessage"),
  signupMessage: document.querySelector("#signupMessage"),
  loginButton: document.querySelector("#loginButton"),
  signupButton: document.querySelector("#signupButton"),
  searchInput: document.querySelector("#searchInput"),
  searchButton: document.querySelector("#searchButton"),
  searchResults: document.querySelector("#searchResults"),
  resultsList: document.querySelector("#resultsList"),
  clearResultsButton: document.querySelector("#clearResultsButton"),
  libraryList: document.querySelector("#libraryList"),
  emptyState: document.querySelector("#emptyState"),
  settingsButton: document.querySelector("#settingsButton"),
  settingsDialog: document.querySelector("#settingsDialog"),
  accountDetails: document.querySelector("#accountDetails"),
  settingsLogoutButton: document.querySelector("#settingsLogoutButton"),
  settingsMessage: document.querySelector("#settingsMessage"),
  profileButton: document.querySelector("#profileButton"),
  notificationsButton: document.querySelector("#notificationsButton"),
  notificationsBadge: document.querySelector("#notificationsBadge"),
  notificationsDialog: document.querySelector("#notificationsDialog"),
  notificationsList: document.querySelector("#notificationsList"),
  template: document.querySelector("#mediaCardTemplate")
};

init();

function init() {
  preventPageZoom();
  bindEvents();
  populateCountries();
  connectSupabase();
  registerServiceWorker();
}

function preventPageZoom() {
  document.addEventListener("gesturestart", (event) => event.preventDefault());
  document.addEventListener("gesturechange", (event) => event.preventDefault());
  document.addEventListener("gestureend", (event) => event.preventDefault());

  let lastTouchEnd = 0;
  document.addEventListener("touchend", (event) => {
    const now = Date.now();
    if (now - lastTouchEnd <= 300) event.preventDefault();
    lastTouchEnd = now;
  }, { passive: false });
}

function bindEvents() {
  els.showLoginButton?.addEventListener("click", () => setAuthMode("login"));
  els.showSignupButton?.addEventListener("click", () => setAuthMode("signup"));
  els.loginForm?.addEventListener("submit", handleLogin);
  els.signupForm?.addEventListener("submit", handleSignup);
  els.searchButton?.addEventListener("click", searchTheTvdb);
  els.searchInput?.addEventListener("keydown", (event) => {
    if (event.key === "Enter") searchTheTvdb();
  });
  els.clearResultsButton?.addEventListener("click", clearResults);
  els.settingsLogoutButton?.addEventListener("click", logout);
  els.settingsButton?.addEventListener("click", () => els.settingsDialog?.showModal());
  els.profileButton?.addEventListener("click", openOwnProfileUrl);
  els.notificationsButton?.addEventListener("click", () => {
    renderNotifications();
    els.notificationsDialog?.showModal();
  });
  els.usernameInput?.addEventListener("input", normalizeUsernameInput);
  els.birthDateInput?.addEventListener("input", formatBirthDateInput);
  els.birthDateInput?.addEventListener("keydown", handleBirthDateSlash);

  document.querySelectorAll("[data-status]").forEach((button) => {
    button.addEventListener("click", () => {
      state.statusFilter = button.dataset.status;
      setActive("[data-status]", button);
      renderLibrary();
    });
  });
}

function loadConfig() {
  const saved = JSON.parse(localStorage.getItem(STORAGE_KEY) || "{}");
  const bundled = window.CONFIG || {};
  return {
    supabaseUrl: saved.supabaseUrl || bundled.SUPABASE_URL || bundled.supabaseUrl || "",
    supabaseAnonKey: saved.supabaseAnonKey || bundled.SUPABASE_ANON_KEY || bundled.supabaseAnonKey || ""
  };
}

async function connectSupabase() {
  if (!state.config.supabaseUrl || !state.config.supabaseAnonKey) {
    showSignedOut("Ajoute tes infos Supabase dans config.js.");
    return;
  }

  if (!window.supabase?.createClient) {
    showSignedOut("Connexion Supabase impossible: la bibliothèque Supabase n'a pas chargé.");
    return;
  }

  state.client = window.supabase.createClient(state.config.supabaseUrl, state.config.supabaseAnonKey);
  const { data } = await state.client.auth.getSession();
  state.session = data.session;

  state.client.auth.onAuthStateChange((_event, session) => {
    state.session = session;
    updateSessionUi();
    if (session) {
      loadLibrary();
      loadFriendNotifications();
    }
  });

  updateSessionUi();
  if (state.session) {
    loadLibrary();
    loadFriendNotifications();
  }
}

function updateSessionUi() {
  if (!state.client) {
    showSignedOut("Ajoute tes infos Supabase dans config.js.");
    return;
  }

  if (!state.session) {
    showSignedOut("");
    return;
  }

  if (window.location.pathname.endsWith("/index.html") || window.location.pathname.endsWith("/")) {
    window.location.href = "app.html";
    return;
  }

  if (els.authPanel) els.authPanel.hidden = true;
  if (els.appControls) els.appControls.hidden = false;
  if (els.libraryPanel) els.libraryPanel.hidden = false;
  if (els.settingsButton) els.settingsButton.hidden = false;
  renderNotificationBadge();
  updateAccountDetails();
}

function showSignedOut(message) {
  if (window.location.pathname.endsWith("/app.html")) {
    window.location.replace("index.html");
    return;
  }

  if (els.authPanel) els.authPanel.hidden = false;
  if (els.appControls) els.appControls.hidden = true;
  if (els.libraryPanel) els.libraryPanel.hidden = true;
  if (els.settingsButton) els.settingsButton.hidden = true;
  if (els.notificationsButton) els.notificationsButton.hidden = true;
  if (els.loginMessage) els.loginMessage.textContent = message;
  if (els.signupMessage) els.signupMessage.textContent = "";
  updateAccountDetails();
}

function setAuthMode(mode) {
  const isLogin = mode === "login";
  els.loginForm.hidden = !isLogin;
  els.signupForm.hidden = isLogin;
  els.showLoginButton.classList.toggle("active", isLogin);
  els.showSignupButton.classList.toggle("active", !isLogin);
  els.loginMessage.textContent = "";
  els.signupMessage.textContent = "";
}

function resetAuthForms() {
  els.loginForm.reset();
  els.signupForm.reset();
  els.countryInput.value = "FR";
  setAuthMode("login");
}

function formatBirthDateInput() {
  const digits = els.birthDateInput.value.replace(/\D/g, "").slice(0, 8);

  if (digits.length <= 2) {
    els.birthDateInput.value = digits.length === 2 ? `${digits}/` : digits;
    return;
  }

  if (digits.length <= 4) {
    els.birthDateInput.value = digits.length === 4
      ? `${digits.slice(0, 2)}/${digits.slice(2, 4)}/`
      : `${digits.slice(0, 2)}/${digits.slice(2)}`;
    return;
  }

  els.birthDateInput.value = `${digits.slice(0, 2)}/${digits.slice(2, 4)}/${digits.slice(4)}`;
}

function handleBirthDateSlash(event) {
  if (event.key !== "/") return;

  event.preventDefault();
  const parts = els.birthDateInput.value.split("/");
  const digits = parts.map((part) => part.replace(/\D/g, ""));

  if (parts.length === 1 && digits[0].length === 1) {
    els.birthDateInput.value = `0${digits[0]}/`;
    return;
  }

  if (parts.length === 2 && digits[1].length === 1) {
    els.birthDateInput.value = `${digits[0].padStart(2, "0")}/0${digits[1]}/`;
  }
}

function normalizeUsernameInput(event) {
  event.target.value = normalizeUsername(event.target.value);
}

function normalizeUsername(value) {
  return String(value || "").toLowerCase().replace(/[^a-z0-9._-]/g, "").slice(0, 28);
}

function isValidUsername(username) {
  return /^[a-z0-9._-]{3,28}$/.test(username);
}

function populateCountries() {
  const countryNames = Intl.DisplayNames
    ? new Intl.DisplayNames(["fr"], { type: "region" })
    : null;
  const countries = COUNTRY_CODES
    .map((code) => ({
      code,
      label: countryNames?.of(code) || code
    }))
    .filter((country) => country.label)
    .sort((a, b) => a.label.localeCompare(b.label, "fr"));

  countries.forEach((country) => {
    const option = document.createElement("option");
    option.value = country.code;
    option.textContent = `${regionToFlag(country.code)} ${country.label}`;
    els.countryInput?.append(option);
  });

  if (els.countryInput) els.countryInput.value = "FR";
}

function regionToFlag(regionCode) {
  return regionCode
    .toUpperCase()
    .replace(/./g, (char) => String.fromCodePoint(char.charCodeAt(0) + 127397));
}

async function handleLogin(event) {
  event.preventDefault();
  if (!state.client) {
    els.loginMessage.textContent = "Configure Supabase dans config.js avant la connexion.";
    return;
  }

  try {
    const { data, error } = await state.client.auth.signInWithPassword({      email: els.loginEmailInput.value.trim(),
      password: els.loginPasswordInput.value
    });

    if (error) {
      els.loginMessage.textContent = formatAuthError(error);
      return;
    }

    state.session = data.session;
    window.location.replace("app.html");
    return;
  } finally {
    setAuthLoading("login", false);
  }
}

async function handleSignup(event) {
  event.preventDefault();
  if (!state.client) {
    els.signupMessage.textContent = "Configure Supabase dans config.js avant la création du compte.";
    return;
  }

  if (!els.signupForm.reportValidity()) return;

  if (els.signupPasswordInput.value !== els.confirmPasswordInput.value) {
    els.signupMessage.textContent = "Les deux mots de passe ne correspondent pas.";
    return;
  }

  const birthDate = getBirthDateValue();
  if (!birthDate) {
    els.signupMessage.textContent = "Entre une date de naissance valide.";
    return;
  }

  try {
    const username = normalizeUsername(els.usernameInput.value);
    els.usernameInput.value = username;

    if (!isValidUsername(username)) {
      els.signupMessage.textContent = "Le display name doit contenir 3 à 28 caractères: lettres minuscules, chiffres, points, tirets ou underscores seulement.";
      return;
    }

    const usernameAvailable = await isUsernameAvailable(state.client, username);

    if (!usernameAvailable) {
      els.signupMessage.textContent = "Ce nom d'utilisateur est déjà utilisé.";
      return;
    }

    const { data, error } = await state.client.auth.signUp({
      email: els.signupEmailInput.value.trim(),
      password: els.signupPasswordInput.value,
      options: {
        emailRedirectTo: getAuthRedirectUrl(),
        data: {
          display_name: username,
          username,
          birth_date: birthDate,
          country: els.countryInput.value,
          country_label: els.countryInput.selectedOptions[0]?.textContent || ""
        }
      }
    });

    if (error) {
      els.signupMessage.textContent = formatAuthError(error);
      return;
    }

    els.signupMessage.textContent = data.session
      ? ""
      : "Compte créé. Si Supabase demande une confirmation, vérifie tes emails.";
  } finally {
    setAuthLoading("signup", false);
  }
}

function getBirthDateValue() {
  const [day = "", month = "", year = ""] = els.birthDateInput.value.split("/");

  if (day.length !== 2 || month.length !== 2 || year.length !== 4) return "";

  const isoDate = `${year}-${month}-${day}`;
  const date = new Date(`${isoDate}T00:00:00`);
  const isValid = date.getFullYear() === Number(year)
    && date.getMonth() + 1 === Number(month)
    && date.getDate() === Number(day);

  return isValid ? isoDate : "";
}

function getAuthRedirectUrl() {
  return `${window.location.origin}${window.location.pathname}`;
}

function setAuthLoading(mode, isLoading, message = "") {
  const button = mode === "login" ? els.loginButton : els.signupButton;
  const messageEl = mode === "login" ? els.loginMessage : els.signupMessage;
  button.disabled = isLoading;
  if (message) messageEl.textContent = message;
}

function formatAuthError(error) {
  const message = error.message || "";
  const normalizedMessage = message.toLowerCase();

  if (normalizedMessage.includes("email rate limit")) {
    return "Supabase a bloqué temporairement les emails. Désactive la confirmation email pendant le dev, attends la fin du blocage, ou crée l'utilisateur directement dans Supabase.";
  }

  if (
    normalizedMessage.includes("already registered") ||
    normalizedMessage.includes("already been registered") ||
    (normalizedMessage.includes("email") && normalizedMessage.includes("exists")) ||
    (normalizedMessage.includes("email") && normalizedMessage.includes("taken"))
  ) {
    return "Un compte existe déjà avec cet email.";
  }

  if (
    normalizedMessage.includes("profiles_username") ||
    (normalizedMessage.includes("duplicate key") && normalizedMessage.includes("username"))
  ) {
    return "Ce nom d'utilisateur est déjà utilisé.";
  }

  return message;
}

async function isUsernameAvailable(client, username) {
  const { data, error } = await client.rpc("is_streamory_username_available", {
    candidate: username
  });

  if (error) return true;
  return data === true;
}

async function logout() {
  if (!state.client) return;
  await state.client.auth.signOut();
  state.library = [];
  els.settingsDialog?.close();
  window.location.href = "index.html";
}

function updateAccountDetails() {
  if (!els.accountDetails || !els.settingsLogoutButton) return;

  if (!state.session) {
    els.accountDetails.textContent = "Connecte-toi pour gérer ton compte.";
    els.settingsLogoutButton.hidden = true;
    return;
  }

  const metadata = state.session.user.user_metadata || {};
  const displayName = metadata.display_name || metadata.username || state.session.user.email;
  els.accountDetails.textContent = `Connecté en tant que ${displayName}.`;
  els.settingsLogoutButton.hidden = false;
}

function openOwnProfileUrl() {
  window.location.href = "profile.html";
}

async function searchTheTvdb() {
  const query = els.searchInput.value.trim();
  if (!query || !state.client) return;

  els.searchResults.hidden = false;
  els.resultsList.innerHTML = `<p class="message">Recherche...</p>`;

  try {
    const session = await state.client.auth.getSession();
    const token = session.data.session?.access_token || state.config.supabaseAnonKey;
    const params = new URLSearchParams({ q: query });
    const language = getCurrentTvdbLanguage();
    if (language) params.set("language", language);
    const response = await fetch(`${state.config.supabaseUrl}/functions/v1/tvdb-search?${params}`, {
      headers: { Authorization: `Bearer ${token}` }
    });

    if (!response.ok) throw new Error(await response.text());
    const payload = await response.json();
    renderSearchResults(payload.data || []);
  } catch (error) {
    els.resultsList.innerHTML = `<p class="message">Recherche impossible: ${escapeHtml(error.message)}</p>`;
  }
}

function renderSearchResults(items) {
  els.resultsList.innerHTML = "";

  if (!items.length) {
    els.resultsList.innerHTML = `<p class="message">Aucun résultat.</p>`;
    return;
  }

  const mediaItems = items
    .map(normalizeTvdbItem)
    .filter((item) => item.mediaType)
    .slice(0, 15);

  if (!mediaItems.length) {
    els.resultsList.innerHTML = `<p class="message">Aucun film ou série trouvé.</p>`;
    return;
  }

  mediaItems.forEach((normalized) => {
    const card = createMediaCard(normalized);
    const addButton = actionButton("Ajouter", () => upsertMedia(normalized, "watchlist"));
    card.querySelector(".card-actions").append(addButton);
    els.resultsList.append(card);
  });
}

function clearResults() {
  els.searchResults.hidden = true;
  els.resultsList.innerHTML = "";
}

async function loadLibrary() {
  if (!els.libraryList) return;

  const { data, error } = await state.client
    .from("user_items")
    .select("*")
    .order("updated_at", { ascending: false });

  if (error) {
    els.libraryList.innerHTML = `<p class="message">Chargement impossible: ${escapeHtml(error.message)}</p>`;
    return;
  }

  state.library = data || [];
  renderLibrary();
}

async function loadFriendNotifications() {
  if (!state.client || !state.session) return;

  const { data, error } = await state.client.rpc("list_streamory_friend_notifications");
  state.friendNotifications = error ? [] : data || [];
  renderNotificationBadge();
  renderNotifications();
}

function renderNotificationBadge() {
  const count = state.friendNotifications.length;
  if (els.notificationsButton) els.notificationsButton.hidden = count === 0;
  if (els.notificationsBadge) {
    els.notificationsBadge.hidden = count === 0;
    els.notificationsBadge.textContent = String(count);
  }
}

function renderNotifications() {
  if (!els.notificationsList) return;

  els.notificationsList.innerHTML = "";

  if (!state.friendNotifications.length) {
    els.notificationsList.append(emptySocialMessage("Aucune notification."));
    return;
  }

  state.friendNotifications.forEach((notification) => {
    els.notificationsList.append(createSocialItem({
      username: notification.username,
      country: notification.country,
      meta: "Demande d'ami",
      actions: [
        { label: "Accepter", onClick: () => answerFriendRequest(notification.request_id, true) },
        { label: "Refuser", danger: true, onClick: () => answerFriendRequest(notification.request_id, false) }
      ]
    }));
  });
}

async function answerFriendRequest(requestId, accept) {
  const functionName = accept
    ? "accept_streamory_friend_request"
    : "reject_streamory_friend_request";

  await state.client.rpc(functionName, { request_id: requestId });
  await loadFriendNotifications();
}

async function upsertMedia(item, status) {
  if (!state.session) return;

  const record = {
    user_id: state.session.user.id,
    tvdb_id: String(item.tvdbId),
    media_type: item.mediaType,
    title: item.title,
    image_url: item.imageUrl,
    year: item.year,
    overview: item.overview,
    status,
    updated_at: new Date().toISOString()
  };

  const { error } = await state.client
    .from("user_items")
    .upsert(record, { onConflict: "user_id,tvdb_id,media_type" });

  if (!error) {
    if (els.libraryList) await loadLibrary();
    clearResults();
  }
}

async function updateStatus(item, status) {
  await state.client
    .from("user_items")
    .update({ status, updated_at: new Date().toISOString() })
    .eq("id", item.id);
  await loadLibrary();
}

async function deleteItem(item) {
  await state.client.from("user_items").delete().eq("id", item.id);
  await loadLibrary();
}

function renderLibrary() {
  if (!els.libraryList || !els.emptyState) return;

  els.libraryList.innerHTML = "";
  const visibleItems = state.library.filter((item) => {
    return state.statusFilter === "all" || item.status === state.statusFilter;
  });

  els.emptyState.hidden = visibleItems.length > 0;

  visibleItems.forEach((item) => {
    const card = createMediaCard({
      title: item.title,
      mediaType: item.media_type,
      imageUrl: item.image_url,
      year: item.year,
      overview: item.overview,
      status: item.status
    });

    Object.entries(STATUSES).forEach(([status, label]) => {
      const button = actionButton(label, () => updateStatus(item, status));
      if (item.status === status) button.classList.add("active");
      card.querySelector(".card-actions").append(button);
    });

    const removeButton = actionButton("Supprimer", () => deleteItem(item));
    removeButton.classList.add("danger");
    card.querySelector(".card-actions").append(removeButton);
    els.libraryList.append(card);
  });
}

function createMediaCard(item) {
  const fragment = els.template.content.cloneNode(true);
  const card = fragment.querySelector(".media-card");
  const poster = card.querySelector(".poster");
  poster.src = item.imageUrl || posterPlaceholder(item.title);
  poster.alt = item.title ? `Affiche de ${item.title}` : "Affiche";
  poster.addEventListener("error", () => {
    poster.src = posterPlaceholder(item.title);
  }, { once: true });
  card.querySelector(".media-kind").textContent = mediaKindLabel(item.mediaType, item.status);
  card.querySelector(".media-title").textContent = item.title || "Sans titre";
  card.querySelector(".media-meta").textContent = item.year || "";
  card.querySelector(".media-overview").textContent = item.overview || "";
  return card;
}

function normalizeTvdbItem(item) {
  const image = item.image_url || item.thumbnail || item.poster || item.image;
  const language = getCurrentTvdbLanguage();
  return {
    tvdbId: normalizeTvdbId(item.tvdb_id || item.id),
    mediaType: normalizeMediaType(item.type),
    title: pickLocalizedValue(item, ["name", "title"], language) || "Sans titre",
    imageUrl: image?.startsWith("http") ? image : image ? `${POSTER_BASE}${image}` : "",
    year: item.year || item.first_air_time?.slice(0, 4) || item.release_year || "",
    overview: pickLocalizedValue(item, ["overview", "description"], language)
  };
}

function mediaKindLabel(type, status) {
  const kind = type === "movie" ? "Film" : "Série";
  return status ? `${kind} · ${STATUSES[status] || status}` : kind;
}

function normalizeMediaType(type) {
  const normalized = String(type || "").toLowerCase();
  if (normalized === "movie" || normalized === "series") return normalized;
  return "";
}

function normalizeTvdbId(value) {
  const text = String(value || "");
  const match = text.match(/\d+/);
  return match ? match[0] : text;
}

function getCurrentTvdbLanguage() {
  const metadata = state.session?.user?.user_metadata || {};
  return getTvdbLanguageForCountry(metadata.country || "FR");
}

function getTvdbLanguageForCountry(country) {
  return COUNTRY_LANGUAGE_CODES[String(country || "").toUpperCase()] || "eng";
}

function pickLocalizedValue(item, fields, language) {
  const translations = item.translations || {};
  const languageValue = getTranslationValue(translations, language, fields);
  if (languageValue) return languageValue;

  const englishValue = getTranslationValue(translations, "eng", fields);
  if (englishValue) return englishValue;

  for (const field of fields) {
    if (item[field]) return item[field];
  }

  return "";
}

function getTranslationValue(translations, language, fields) {
  if (!translations || !language) return "";

  const directTranslation = translations[language];
  const directValue = normalizeTranslationValue(directTranslation, fields);
  if (directValue) return directValue;

  if (!Array.isArray(translations)) return "";

  const languageTranslation = translations.find((translation) => {
    return [translation.language, translation.language_code, translation.iso_639_2, translation.iso639_2]
      .filter(Boolean)
      .map((value) => String(value).toLowerCase())
      .includes(language);
  });

  return normalizeTranslationValue(languageTranslation, fields);
}

function normalizeTranslationValue(translation, fields) {
  if (!translation) return "";
  if (typeof translation === "string") return translation;

  for (const field of fields) {
    if (translation[field]) return translation[field];
  }

  return "";
}

function actionButton(label, onClick) {
  const button = document.createElement("button");
  button.type = "button";
  button.className = "filter";
  button.textContent = label;
  button.addEventListener("click", onClick);
  return button;
}

function createSocialItem({ username, country, meta = "", actions = [] }) {
  const item = document.createElement("div");
  item.className = "social-item";

  const user = document.createElement("div");
  user.className = "social-user";

  const avatar = document.createElement("div");
  avatar.className = "social-avatar";
  avatar.textContent = "👤";

  const text = document.createElement("div");
  const name = document.createElement("p");
  name.className = "social-name";
  name.textContent = username || "Utilisateur";

  const details = document.createElement("p");
  details.className = "social-meta";
  details.textContent = [country ? regionToFlag(country) : "", meta].filter(Boolean).join(" · ");

  text.append(name, details);
  user.append(avatar, text);
  item.append(user);

  if (actions.length) {
    const actionList = document.createElement("div");
    actionList.className = "social-actions";

    actions.forEach((action) => {
      const button = document.createElement("button");
      button.type = "button";
      button.className = action.danger ? "filter danger" : "filter";
      button.textContent = action.label;
      button.disabled = action.disabled === true;
      button.addEventListener("click", action.onClick);
      actionList.append(button);
    });

    item.append(actionList);
  }

  return item;
}

function emptySocialMessage(message) {
  const empty = document.createElement("p");
  empty.className = "message";
  empty.textContent = message;
  return empty;
}

function setActive(selector, activeButton) {
  document.querySelectorAll(selector).forEach((button) => {
    button.classList.toggle("active", button === activeButton);
  });
}

function posterPlaceholder(title = "Sans titre") {
  const lines = splitPlaceholderTitle(title);
  const lineHeight = 18;
  const startY = 120 - ((lines.length - 1) * lineHeight) / 2;
  const text = lines.map((line, index) => (
    `<text x="80" y="${startY + index * lineHeight}" text-anchor="middle">${escapeSvgText(line)}</text>`
  )).join("");
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="160" height="240" viewBox="0 0 160 240"><rect width="160" height="240" fill="#20242a"/><g fill="#f4f6fb" font-family="Arial, Helvetica, sans-serif" font-size="15" font-weight="700">${text}</g></svg>`;
  return `data:image/svg+xml,${encodeURIComponent(svg)}`;
}

function splitPlaceholderTitle(value) {
  const words = String(value || "Sans titre").trim().split(/\s+/);
  const lines = [];
  let line = "";

  words.forEach((word) => {
    const nextLine = line ? `${line} ${word}` : word;
    if (nextLine.length <= 14) {
      line = nextLine;
      return;
    }
    if (line) lines.push(line);
    line = word;
  });

  if (line) lines.push(line);
  return (lines.length ? lines : ["Sans titre"]).slice(0, 4);
}

function escapeSvgText(value) {
  return String(value).replace(/[&<>"']/g, (char) => (
    { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#039;" }[char]
  ));
}

function escapeHtml(value) {
  return value.replace(/[&<>"']/g, (char) => {
    return ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#039;" })[char];
  });
}

function registerServiceWorker() {
  if (!("serviceWorker" in navigator)) return;

  if (isLocalDevHost()) {
    navigator.serviceWorker.getRegistrations()
      .then((registrations) => registrations.forEach((registration) => registration.unregister()))
      .catch(() => {});
    return;
  }

  navigator.serviceWorker.register("service-worker.js").catch(() => {});
}

function isLocalDevHost() {
  return [
    "localhost",
    "127.0.0.1",
    "172.20.10.14"
  ].includes(window.location.hostname);
}
