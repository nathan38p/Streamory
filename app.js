const STORAGE_KEY = "streamory-config";
const POSTER_BASE = "https://artworks.thetvdb.com";
const STATUSES = {
  watchlist: "À voir",
  watching: "En cours",
  watched: "Vu"
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
  mediaType: "series",
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
  els.notificationsButton?.addEventListener("click", () => {
    renderNotifications();
    els.notificationsDialog?.showModal();
  });
  els.birthDateInput?.addEventListener("input", formatBirthDateInput);
  els.birthDateInput?.addEventListener("keydown", handleBirthDateSlash);

  document.querySelectorAll("[data-type]").forEach((button) => {
    button.addEventListener("click", () => {
      state.mediaType = button.dataset.type;
      setActive("[data-type]", button);
      clearResults();
    });
  });

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
  if (els.notificationsButton) els.notificationsButton.hidden = false;
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
    const username = els.usernameInput.value.trim();
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

async function searchTheTvdb() {
  const query = els.searchInput.value.trim();
  if (!query || !state.client) return;

  els.searchResults.hidden = false;
  els.resultsList.innerHTML = `<p class="message">Recherche...</p>`;

  try {
    const session = await state.client.auth.getSession();
    const token = session.data.session?.access_token || state.config.supabaseAnonKey;
    const params = new URLSearchParams({ q: query, type: state.mediaType });
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

  items.slice(0, 15).forEach((item) => {
    const normalized = normalizeTvdbItem(item);
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
  if (!els.notificationsBadge) return;

  const count = state.friendNotifications.length;
  els.notificationsBadge.hidden = count === 0;
  els.notificationsBadge.textContent = String(count);
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
    await loadLibrary();
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
  poster.src = item.imageUrl || posterPlaceholder();
  poster.alt = item.title ? `Affiche de ${item.title}` : "Affiche";
  card.querySelector(".media-kind").textContent = mediaKindLabel(item.mediaType, item.status);
  card.querySelector(".media-title").textContent = item.title || "Sans titre";
  card.querySelector(".media-meta").textContent = item.year || "";
  card.querySelector(".media-overview").textContent = item.overview || "";
  return card;
}

function normalizeTvdbItem(item) {
  const image = item.image_url || item.thumbnail || item.poster || item.image;
  return {
    tvdbId: item.tvdb_id || item.id,
    mediaType: item.type || state.mediaType,
    title: item.name || item.title || item.translations?.fra || "Sans titre",
    imageUrl: image?.startsWith("http") ? image : image ? `${POSTER_BASE}${image}` : "",
    year: item.year || item.first_air_time?.slice(0, 4) || item.release_year || "",
    overview: item.overview || item.description || ""
  };
}

function mediaKindLabel(type, status) {
  const kind = type === "movie" ? "Film" : "Série";
  return status ? `${kind} · ${STATUSES[status] || status}` : kind;
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

function posterPlaceholder() {
  return "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='160' height='240' viewBox='0 0 160 240'%3E%3Crect width='160' height='240' fill='%2320242a'/%3E%3Cpath d='M42 72h76v96H42z' fill='none' stroke='%236ee7b7' stroke-width='6'/%3E%3Cpath d='M55 92h50M55 112h50M55 132h32' stroke='%23a7adb6' stroke-width='6' stroke-linecap='round'/%3E%3C/svg%3E";
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
