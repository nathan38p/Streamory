import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const STORAGE_KEY = "streamory-config";
const POSTER_BASE = "https://artworks.thetvdb.com";
const STATUSES = {
  watchlist: "À voir",
  watching: "En cours",
  watched: "Vu"
};

const state = {
  client: null,
  session: null,
  mediaType: "series",
  statusFilter: "all",
  library: [],
  config: loadConfig()
};

const els = {
  authPanel: document.querySelector("#authPanel"),
  appControls: document.querySelector("#appControls"),
  libraryPanel: document.querySelector("#libraryPanel"),
  loginForm: document.querySelector("#loginForm"),
  emailInput: document.querySelector("#emailInput"),
  authMessage: document.querySelector("#authMessage"),
  searchInput: document.querySelector("#searchInput"),
  searchButton: document.querySelector("#searchButton"),
  searchResults: document.querySelector("#searchResults"),
  resultsList: document.querySelector("#resultsList"),
  clearResultsButton: document.querySelector("#clearResultsButton"),
  libraryList: document.querySelector("#libraryList"),
  emptyState: document.querySelector("#emptyState"),
  logoutButton: document.querySelector("#logoutButton"),
  settingsButton: document.querySelector("#settingsButton"),
  settingsDialog: document.querySelector("#settingsDialog"),
  supabaseUrlInput: document.querySelector("#supabaseUrlInput"),
  supabaseAnonInput: document.querySelector("#supabaseAnonInput"),
  saveSettingsButton: document.querySelector("#saveSettingsButton"),
  settingsMessage: document.querySelector("#settingsMessage"),
  template: document.querySelector("#mediaCardTemplate")
};

init();

function init() {
  bindEvents();
  fillSettingsForm();
  connectSupabase();
  registerServiceWorker();
}

function bindEvents() {
  els.loginForm.addEventListener("submit", handleLogin);
  els.searchButton.addEventListener("click", searchTheTvdb);
  els.searchInput.addEventListener("keydown", (event) => {
    if (event.key === "Enter") searchTheTvdb();
  });
  els.clearResultsButton.addEventListener("click", clearResults);
  els.logoutButton.addEventListener("click", logout);
  els.settingsButton.addEventListener("click", () => els.settingsDialog.showModal());
  els.saveSettingsButton.addEventListener("click", saveSettings);

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
  return {
    supabaseUrl: saved.supabaseUrl || window.STREAMORY_CONFIG?.supabaseUrl || "",
    supabaseAnonKey: saved.supabaseAnonKey || window.STREAMORY_CONFIG?.supabaseAnonKey || ""
  };
}

function fillSettingsForm() {
  els.supabaseUrlInput.value = state.config.supabaseUrl;
  els.supabaseAnonInput.value = state.config.supabaseAnonKey;
}

async function connectSupabase() {
  if (!state.config.supabaseUrl || !state.config.supabaseAnonKey) {
    showSignedOut("Ajoute tes infos Supabase dans les réglages.");
    return;
  }

  state.client = createClient(state.config.supabaseUrl, state.config.supabaseAnonKey);
  const { data } = await state.client.auth.getSession();
  state.session = data.session;

  state.client.auth.onAuthStateChange((_event, session) => {
    state.session = session;
    updateSessionUi();
    if (session) loadLibrary();
  });

  updateSessionUi();
  if (state.session) loadLibrary();
}

function updateSessionUi() {
  if (!state.client) {
    showSignedOut("Ajoute tes infos Supabase dans les réglages.");
    return;
  }

  if (!state.session) {
    showSignedOut("");
    return;
  }

  els.authPanel.hidden = true;
  els.appControls.hidden = false;
  els.libraryPanel.hidden = false;
}

function showSignedOut(message) {
  els.authPanel.hidden = false;
  els.appControls.hidden = true;
  els.libraryPanel.hidden = true;
  els.authMessage.textContent = message;
}

async function handleLogin(event) {
  event.preventDefault();
  if (!state.client) {
    els.authMessage.textContent = "Configure Supabase avant la connexion.";
    return;
  }

  els.authMessage.textContent = "Envoi du lien...";
  const { error } = await state.client.auth.signInWithOtp({
    email: els.emailInput.value,
    options: { emailRedirectTo: window.location.href }
  });

  els.authMessage.textContent = error
    ? error.message
    : "Lien envoyé. Ouvre-le sur ton iPhone pour te connecter.";
}

async function logout() {
  if (!state.client) return;
  await state.client.auth.signOut();
  state.library = [];
  renderLibrary();
}

function saveSettings() {
  state.config = {
    supabaseUrl: els.supabaseUrlInput.value.trim().replace(/\/$/, ""),
    supabaseAnonKey: els.supabaseAnonInput.value.trim()
  };

  localStorage.setItem(STORAGE_KEY, JSON.stringify(state.config));
  els.settingsMessage.textContent = "Réglages enregistrés.";
  connectSupabase();
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
  if ("serviceWorker" in navigator) {
    navigator.serviceWorker.register("service-worker.js").catch(() => {});
  }
}
