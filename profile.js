

const profileEls = {
  profileUsername: document.getElementById("profileUsername"),
  profileCountryFlag: document.getElementById("profileCountryFlag"),
  settingsButton: document.getElementById("settingsButton"),
  settingsDialog: document.getElementById("settingsDialog"),
  friendsButton: document.getElementById("friendsButton"),
  friendsDialog: document.getElementById("friendsDialog"),
  friendsList: document.getElementById("friendsList"),
  friendSearchInput: document.getElementById("friendSearchInput"),
  friendSearchButton: document.getElementById("friendSearchButton"),
  friendSearchMessage: document.getElementById("friendSearchMessage"),
  friendSearchResults: document.getElementById("friendSearchResults"),
  notificationsButton: document.getElementById("notificationsButton"),
  notificationsBadge: document.getElementById("notificationsBadge"),
  notificationsDialog: document.getElementById("notificationsDialog"),
  notificationsList: document.getElementById("notificationsList"),
  profileSeriesRail: document.getElementById("profileSeriesRail"),
  profileSeriesEmpty: document.getElementById("profileSeriesEmpty"),
  profileMoviesRail: document.getElementById("profileMoviesRail"),
  profileMoviesEmpty: document.getElementById("profileMoviesEmpty"),
  editUsername: document.getElementById("editUsername"),
  editCountry: document.getElementById("editCountry"),
  editEmail: document.getElementById("editEmail"),
  editCurrentPassword: document.getElementById("editCurrentPassword"),
  editNewPassword: document.getElementById("editNewPassword"),
  tvtimeMoviesFile: document.getElementById("tvtimeMoviesFile"),
  tvtimeSeriesFile: document.getElementById("tvtimeSeriesFile"),
  importTvtimeButton: document.getElementById("importTvtimeButton"),
  tvtimeImportMessage: document.getElementById("tvtimeImportMessage"),
  tvtimeImportContainer: null,
  saveProfileButton: document.getElementById("saveProfileButton"),
  logoutButton: document.getElementById("logoutButton")
};

const PROFILE_COUNTRY_CODES = ["FR", "BE", "CH", "CA", "US", "GB", "ES", "IT", "DE", "PT"];
const TVTIME_IMPORT_CHUNK_SIZE = 500;

let profileClient = null;
let profileSession = null;
let profileFriends = [];
let profileNotifications = [];
let profileSeries = [];
let profileMovies = [];

initProfilePage();

function initProfilePage() {
  preventPageZoom();
  populateProfileCountries();
  bindProfileEvents();
  resolveTvtimeImportContainer();
  connectProfileSupabase();
}

function getSupabaseConfig() {
  const config = window.CONFIG || {};
  const legacyConfig = window.STREAMORY_CONFIG || {};

  return {
    supabaseUrl: config.SUPABASE_URL || config.supabaseUrl || legacyConfig.supabaseUrl || "",
    supabaseAnonKey: config.SUPABASE_ANON_KEY || config.supabaseAnonKey || legacyConfig.supabaseAnonKey || ""
  };
}

async function connectProfileSupabase() {
  const { supabaseUrl, supabaseAnonKey } = getSupabaseConfig();

  if (!window.supabase || !supabaseUrl || !supabaseAnonKey) {
    window.location.replace("index.html");
    return;
  }

  profileClient = window.supabase.createClient(supabaseUrl, supabaseAnonKey);

  const { data } = await profileClient.auth.getSession();
  profileSession = data.session;

  if (!profileSession) {
    window.location.replace("index.html");
    return;
  }

  renderProfile();
  syncLegacyDisplayName();
  loadProfileSocialData();
  openSettingsFromUrl();

  profileClient.auth.onAuthStateChange((_event, session) => {
    profileSession = session;

    if (!profileSession) {
      window.location.replace("index.html");
      return;
    }

    renderProfile();
    syncLegacyDisplayName();
    loadProfileSocialData();
    openSettingsFromUrl();
  });
}

function bindProfileEvents() {
  profileEls.settingsButton?.addEventListener("click", () => {
    fillSettingsForm();
    updateTvtimeImportVisibility();
    profileEls.settingsDialog?.showModal();
  });

  profileEls.friendsButton?.addEventListener("click", () => {
    renderFriendsList();
    profileEls.friendsDialog?.showModal();
  });

  profileEls.friendSearchButton?.addEventListener("click", searchFriends);
  profileEls.friendSearchInput?.addEventListener("keydown", (event) => {
    if (event.key === "Enter") {
      event.preventDefault();
      searchFriends();
    }
  });

  profileEls.editUsername?.addEventListener("input", normalizeUsernameInput);
  profileEls.notificationsButton?.addEventListener("click", () => {
    renderNotificationsList();
    profileEls.notificationsDialog?.showModal();
  });

  profileEls.saveProfileButton?.addEventListener("click", saveProfile);
  profileEls.importTvtimeButton?.addEventListener("click", importTvtimeData);
  profileEls.logoutButton?.addEventListener("click", logoutProfile);
}

function openSettingsFromUrl() {
  if (new URLSearchParams(window.location.search).get("settings") !== "1") return;
  if (profileEls.settingsDialog?.open) return;

  fillSettingsForm();
  updateTvtimeImportVisibility();
  profileEls.settingsDialog?.showModal();
}

function renderProfile() {
  const user = profileSession?.user;
  if (!user) return;

  const metadata = user.user_metadata || {};
  const username = getProfileDisplayName(user);
  const country = metadata.country || "FR";

  if (profileEls.profileUsername) profileEls.profileUsername.textContent = username;
  if (profileEls.profileCountryFlag) profileEls.profileCountryFlag.textContent = regionToFlag(country);
}

function getPublicProfileUrl(username) {
  const url = new URL("user.html", window.location.href);
  url.searchParams.set("u", normalizeUsername(username));
  return url.href;
}

function openPublicProfile(username) {
  window.location.href = getPublicProfileUrl(username);
}

async function loadProfileSocialData() {
  if (!profileClient || !profileSession?.user) return;

  await Promise.all([
    loadFriends(),
    loadNotifications(),
    loadProfileLibrary()
  ]);
}

async function loadFriends() {
  const { data, error } = await profileClient.rpc("list_streamory_friends");

  if (error) {
    profileFriends = [];
  } else {
    profileFriends = data || [];
  }

  renderFriendCount();
  renderFriendsList();
}

async function loadNotifications() {
  const { data, error } = await profileClient.rpc("list_streamory_friend_notifications");

  if (error) {
    profileNotifications = [];
  } else {
    profileNotifications = data || [];
  }

  renderNotificationBadge();
  renderNotificationsList();
}

function renderFriendCount() {
  if (!profileEls.friendsButton) return;

  const count = profileFriends.length;
  profileEls.friendsButton.textContent = `${count} ami${count > 1 ? "s" : ""}`;
}

function renderNotificationBadge() {
  const count = profileNotifications.length;
  if (profileEls.notificationsButton) profileEls.notificationsButton.hidden = count === 0;
  if (profileEls.notificationsBadge) {
    profileEls.notificationsBadge.hidden = count === 0;
    profileEls.notificationsBadge.textContent = String(count);
  }
}

function renderFriendsList() {
  if (!profileEls.friendsList) return;

  profileEls.friendsList.innerHTML = "";

  if (!profileFriends.length) {
    profileEls.friendsList.append(emptySocialMessage("Aucun ami pour le moment."));
    return;
  }

  profileFriends.forEach((friend) => {
    profileEls.friendsList.append(createSocialItem({
      username: friend.username,
      country: friend.country,
      meta: "Ami",
      actions: [
        { label: "Profil", onClick: () => openPublicProfile(friend.username) }
      ]
    }));
  });
}

function renderNotificationsList() {
  if (!profileEls.notificationsList) return;

  profileEls.notificationsList.innerHTML = "";

  if (!profileNotifications.length) {
    profileEls.notificationsList.append(emptySocialMessage("Aucune notification."));
    return;
  }

  profileNotifications.forEach((notification) => {
    const item = createSocialItem({
      username: notification.username,
      country: notification.country,
      meta: "Demande d'ami",
      actions: [
        { label: "Accepter", onClick: () => answerFriendRequest(notification.request_id, true) },
        { label: "Refuser", danger: true, onClick: () => answerFriendRequest(notification.request_id, false) }
      ]
    });

    profileEls.notificationsList.append(item);
  });
}

async function loadProfileLibrary() {
  const [seriesResult, moviesResult] = await Promise.all([
    profileClient
      .from("user_items")
      .select("id,title,tvdb_id,image_url,media_type,status,updated_at")
      .eq("media_type", "series")
      .order("updated_at", { ascending: false })
      .limit(20),
    profileClient
      .from("user_items")
      .select("id,title,tvdb_id,image_url,media_type,status,updated_at")
      .eq("media_type", "movie")
      .order("updated_at", { ascending: false })
      .limit(20)
  ]);

  profileSeries = seriesResult.error ? [] : seriesResult.data || [];
  profileMovies = moviesResult.error ? [] : moviesResult.data || [];

  await markTvtimeImportDoneIfExistingData();
  updateTvtimeImportVisibility();
  await backfillMissingProfilePosters();
  renderProfileRails();
}

async function backfillMissingProfilePosters() {
  if (!profileClient) return;

  const missingItems = [...profileSeries, ...profileMovies]
    .filter((item) => item.tvdb_id && !item.image_url)
    .slice(0, 10);

  if (!missingItems.length) return;

  for (const item of missingItems) {
    try {
      const details = await fetchTheTvdbDetails(item.tvdb_id, item.media_type);
      if (!details.image_url) continue;

      item.image_url = details.image_url;

      await profileClient
        .from("user_items")
        .update({ image_url: details.image_url })
        .eq("id", item.id);
    } catch (_error) {
      // Garde le placeholder si TheTVDB ne renvoie pas d'affiche.
    }
  }
}

function renderProfileRails() {
  renderProfileRail({
    rail: profileEls.profileSeriesRail,
    empty: profileEls.profileSeriesEmpty,
    items: profileSeries
  });
  renderProfileRail({
    rail: profileEls.profileMoviesRail,
    empty: profileEls.profileMoviesEmpty,
    items: profileMovies
  });
}

function renderProfileRail({ rail, empty, items }) {
  if (!rail) return;

  rail.innerHTML = "";
  if (empty) empty.hidden = items.length > 0;
  rail.hidden = items.length === 0;

  items.forEach((item) => {
    rail.append(createProfilePoster(item));
  });
}

function createProfilePoster(item) {
  const figure = document.createElement("figure");
  figure.className = "profile-poster-item";

  const link = document.createElement("a");
  link.href = getMediaDetailUrl(item);
  link.setAttribute("aria-label", `Voir ${item.title || "ce titre"}`);

  const image = document.createElement("img");
  image.src = item.image_url || posterPlaceholder();
  image.alt = item.title ? `Affiche de ${item.title}` : "Affiche";
  image.loading = "lazy";
  image.addEventListener("error", () => {
    image.src = posterPlaceholder();
  }, { once: true });

  const caption = document.createElement("figcaption");
  caption.textContent = item.title || "Sans titre";

  link.append(image, caption);
  figure.append(link);
  return figure;
}

function getMediaDetailUrl(item) {
  const page = item.media_type === "movie" ? "film.html" : "tvshow.html";
  return `${page}?id=${encodeURIComponent(normalizeTvdbId(item.tvdb_id))}`;
}

async function searchFriends() {
  if (!profileClient || !profileEls.friendSearchInput || !profileEls.friendSearchResults) return;

  const query = profileEls.friendSearchInput.value.trim();
  profileEls.friendSearchResults.innerHTML = "";
  profileEls.friendSearchMessage.textContent = "";

  if (query.length < 2) {
    profileEls.friendSearchMessage.textContent = "Entre au moins 2 caractères.";
    return;
  }

  const { data, error } = await profileClient.rpc("search_streamory_profiles", {
    candidate: query
  });

  if (error) {
    profileEls.friendSearchMessage.textContent = "Recherche impossible.";
    return;
  }

  if (!data?.length) {
    profileEls.friendSearchResults.append(emptySocialMessage("Aucun utilisateur trouvé."));
    return;
  }

  data.forEach((user) => {
    const alreadyLinked = ["pending", "accepted"].includes(user.relationship_status);
    const label = user.relationship_status === "accepted"
      ? "Déjà ami"
      : user.relationship_status === "pending"
        ? "Demande envoyée"
        : "Ajouter";

    const item = createSocialItem({
      username: user.username,
      country: user.country,
      meta: user.relationship_status === "accepted" ? "Ami" : "",
      actions: [
        {
          label,
          disabled: alreadyLinked,
          onClick: () => sendFriendRequest(user.user_id)
        }
      ]
    });

    profileEls.friendSearchResults.append(item);
  });
}

async function sendFriendRequest(userId) {
  const { error } = await profileClient.rpc("send_streamory_friend_request", {
    target_user_id: userId
  });

  if (error) {
    profileEls.friendSearchMessage.textContent = "Demande impossible.";
    return;
  }

  profileEls.friendSearchMessage.textContent = "Demande envoyée.";
  await searchFriends();
}

async function answerFriendRequest(requestId, accept) {
  const functionName = accept
    ? "accept_streamory_friend_request"
    : "reject_streamory_friend_request";

  await profileClient.rpc(functionName, { request_id: requestId });
  await loadProfileSocialData();
}

function fillSettingsForm() {
  const user = profileSession?.user;
  if (!user) return;

  const metadata = user.user_metadata || {};

  if (profileEls.editUsername) profileEls.editUsername.value = normalizeUsername(metadata.display_name || metadata.username || "");
  if (profileEls.editCountry) profileEls.editCountry.value = metadata.country || "FR";
  if (profileEls.editEmail) profileEls.editEmail.value = user.email || "";
  if (profileEls.editCurrentPassword) profileEls.editCurrentPassword.value = "";
  if (profileEls.editNewPassword) profileEls.editNewPassword.value = "";
}

async function saveProfile() {
  if (!profileClient || !profileSession?.user) return;

  const currentUser = profileSession.user;
  const currentMetadata = currentUser.user_metadata || {};

  const username = normalizeUsername(profileEls.editUsername?.value || "");
  const country = profileEls.editCountry?.value || "FR";
  const email = profileEls.editEmail?.value.trim() || currentUser.email;
  const currentPassword = profileEls.editCurrentPassword?.value || "";
  const newPassword = profileEls.editNewPassword?.value || "";
  const currentUsername = getProfileDisplayName(currentUser);

  if (profileEls.editUsername) profileEls.editUsername.value = username;

  if (!isValidUsername(username)) {
    alert("Le display name doit contenir 3 à 28 caractères: lettres minuscules, chiffres, points, tirets ou underscores seulement.");
    return;
  }

  const updatePayload = {
    data: {
      ...currentMetadata,
      display_name: username,
      username,
      country
    }
  };

  if (email && email !== currentUser.email) {
    updatePayload.email = email;
  }

  if (currentPassword || newPassword) {
    if (!currentPassword || !newPassword) {
      alert("Entre l'ancien mot de passe et le nouveau mot de passe.");
      return;
    }

    if (newPassword.length < 6) {
      alert("Le nouveau mot de passe doit contenir au moins 6 caractères.");
      return;
    }
  }

  profileEls.saveProfileButton.disabled = true;

  try {
    if (username !== normalizeUsername(currentUsername)) {
      const isAvailable = await isUsernameAvailable(username);

      if (!isAvailable) {
        alert("Ce nom d'utilisateur est déjà utilisé.");
        return;
      }
    }

    if (newPassword) {
      const passwordIsValid = await verifyCurrentPassword(currentUser.email, currentPassword);

      if (!passwordIsValid) {
        alert("L'ancien mot de passe est incorrect.");
        return;
      }

      updatePayload.password = newPassword;
    }

    const { data, error } = await profileClient.auth.updateUser(updatePayload);

    if (error) {
      alert(formatProfileError(error));
      return;
    }

    const refreshed = await profileClient.auth.getSession();
    profileSession = refreshed.data.session || {
      access_token: profileSession.access_token,
      user: data.user
    };

    renderProfile();
    profileEls.settingsDialog?.close();
  } finally {
    profileEls.saveProfileButton.disabled = false;
  }
}

async function verifyCurrentPassword(email, password) {
  if (!email || !password) return false;

  const { error } = await profileClient.auth.signInWithPassword({
    email,
    password
  });

  return !error;
}

async function importTvtimeData() {
  if (!profileClient || !profileSession?.user) return;

  const moviesFile = profileEls.tvtimeMoviesFile?.files?.[0];
  const seriesFile = profileEls.tvtimeSeriesFile?.files?.[0];

  if (!moviesFile || !seriesFile) {
    setTvtimeImportMessage("Choisis le fichier films et le fichier séries.");
    return;
  }

  setTvtimeImportLoading(true, "Lecture des fichiers TVTime...");

  try {
    const [moviesData, seriesData] = await Promise.all([
      readJsonFile(moviesFile),
      readJsonFile(seriesFile)
    ]);

    if (!Array.isArray(moviesData) || !Array.isArray(seriesData)) {
      throw new Error("Les exports TVTime doivent être des listes JSON.");
    }

    const importData = buildTvtimeImportData({
      movies: moviesData,
      series: seriesData,
      userId: profileSession.user.id
    });

    setTvtimeImportMessage(`Récupération des affiches TheTVDB pour ${importData.items.length} titres...`);
    const enrichedItems = await enrichTvtimeItemsWithTheTvdb(importData.items);

    setTvtimeImportMessage(`Import de ${enrichedItems.length} titres et ${importData.episodeWatches.length} épisodes vus...`);

    await upsertInChunks("user_items", enrichedItems, "user_id,tvdb_id,media_type");
    await upsertInChunks("user_episode_watches", importData.episodeWatches, "user_id,series_tvdb_id,episode_tvdb_id");
    await loadProfileLibrary();
    await markTvtimeImportDone();
    updateTvtimeImportVisibility();

    setTvtimeImportMessage(`Import terminé: ${importData.seriesCount} séries, ${importData.movieCount} films, ${importData.episodeWatches.length} épisodes vus.`);
  } catch (error) {
    setTvtimeImportMessage(`Import impossible: ${error.message || "erreur inconnue"}`);
  } finally {
    setTvtimeImportLoading(false);
  }
}

function resolveTvtimeImportContainer() {
  const anchor = profileEls.importTvtimeButton || profileEls.tvtimeMoviesFile || profileEls.tvtimeSeriesFile;
  if (!anchor) return;

  profileEls.tvtimeImportContainer = anchor.closest(".settings-section, .form-section, .dialog-section, fieldset, section, article") || anchor.parentElement;
}

function getTvtimeImportStorageKey() {
  const userId = profileSession?.user?.id || "anonymous";
  return `streamory_tvtime_import_done_${userId}`;
}

function isTvtimeImportDone() {
  const metadata = profileSession?.user?.user_metadata || {};
  return metadata.tvtime_import_done === true || localStorage.getItem(getTvtimeImportStorageKey()) === "1";
}

function updateTvtimeImportVisibility() {
  if (!profileEls.tvtimeImportContainer) resolveTvtimeImportContainer();
  if (!profileEls.tvtimeImportContainer) return;

  const shouldHide = isTvtimeImportDone();
  profileEls.tvtimeImportContainer.hidden = shouldHide;
}

async function markTvtimeImportDone() {
  if (!profileClient || !profileSession?.user) return;

  localStorage.setItem(getTvtimeImportStorageKey(), "1");

  const metadata = profileSession.user.user_metadata || {};
  if (metadata.tvtime_import_done === true) return;

  const { data, error } = await profileClient.auth.updateUser({
    data: {
      ...metadata,
      tvtime_import_done: true,
      tvtime_imported_at: new Date().toISOString()
    }
  });

  if (!error && data.user) {
    profileSession = {
      ...profileSession,
      user: data.user
    };
  }
}

async function markTvtimeImportDoneIfExistingData() {
  if (isTvtimeImportDone()) return;
  if (!profileClient || !profileSession?.user) return;

  const hasImportedEpisodeWatches = await hasExistingTvtimeEpisodeWatches();
  if (!hasImportedEpisodeWatches) return;

  await markTvtimeImportDone();
}

async function hasExistingTvtimeEpisodeWatches() {
  const { count, error } = await profileClient
    .from("user_episode_watches")
    .select("id", { count: "exact", head: true })
    .limit(1);

  if (error) return false;
  return Number(count || 0) > 0;
}

async function enrichTvtimeItemsWithTheTvdb(items) {
  const enrichedItems = [];

  for (let index = 0; index < items.length; index += 1) {
    const item = items[index];
    setTvtimeImportMessage(`Récupération des affiches TheTVDB ${index + 1}/${items.length}...`);

    try {
      const details = await fetchTheTvdbDetails(item.tvdb_id, item.media_type);
      enrichedItems.push({
        ...item,
        title: details.title || item.title,
        year: details.year || item.year || null,
        overview: details.overview || item.overview || null,
        image_url: details.image_url || item.image_url || null
      });
    } catch (_error) {
      enrichedItems.push(item);
    }
  }

  return enrichedItems;
}

async function fetchTheTvdbDetails(tvdbId, mediaType) {
  if (!tvdbId) return {};
  const normalizedTvdbId = normalizeTvdbId(tvdbId);

  const endpoint = mediaType === "movie"
    ? `movies/${encodeURIComponent(normalizedTvdbId)}/extended`
    : `series/${encodeURIComponent(normalizedTvdbId)}/extended`;

  const { data, error } = await profileClient.functions.invoke("tvdb-search", {
    body: {
      endpoint
    }
  });

  if (error) throw error;

  const payload = data?.data || data;
  const primaryArtwork = findPrimaryTheTvdbArtwork(payload);

  return {
    title: payload?.name || payload?.title || payload?.seriesName || "",
    year: extractTheTvdbYear(payload),
    overview: payload?.overview || payload?.description || "",
    image_url: normalizeTheTvdbImageUrl(
      payload?.image ||
      payload?.image_url ||
      payload?.poster ||
      payload?.poster_url ||
      primaryArtwork?.image ||
      primaryArtwork?.thumbnail ||
      primaryArtwork?.url
    )  };
}

function extractTheTvdbYear(payload) {
  const rawDate = payload?.firstAired || payload?.released || payload?.releaseDate || payload?.year;
  if (!rawDate) return null;

  const match = String(rawDate).match(/\d{4}/);
  return match ? match[0] : null;
}

function findPrimaryTheTvdbArtwork(payload) {
  const artworks = Array.isArray(payload?.artworks) ? payload.artworks : [];
  if (artworks.length === 0) return null;

  return artworks.find((artwork) => {
    const type = String(artwork?.type || artwork?.typeName || artwork?.artworkType || "").toLowerCase();
    return type.includes("poster") || type.includes("cover");
  }) || artworks[0];
}

function normalizeTheTvdbImageUrl(value) {
  if (!value) return null;
  const url = String(value);

  if (url.startsWith("http://") || url.startsWith("https://")) return url;
  if (url.startsWith("/")) return `https://artworks.thetvdb.com${url}`;

  return `https://artworks.thetvdb.com/banners/${url}`;
}

function buildTvtimeImportData({ movies, series, userId }) {
  const movieItems = movies
    .filter((movie) => getTvdbId(movie))
    .map((movie) => ({
      user_id: userId,
      tvdb_id: getTvdbId(movie),
      media_type: "movie",
      title: String(movie.title || "Film sans titre"),
      year: movie.year ? String(movie.year) : null,
      overview: null,
      image_url: null,
      status: movie.is_watched ? "watched" : "watchlist",
      updated_at: normalizeTvtimeDate(movie.watched_at || movie.created_at) || new Date().toISOString()
    }));

  const seriesItems = [];
  const episodeWatches = [];

  series
    .filter((show) => getTvdbId(show))
    .forEach((show) => {
      const episodeStats = getSeriesEpisodeStats(show);
      const seriesTvdbId = getTvdbId(show);
      const seriesTitle = String(show.title || "Série sans titre");

      seriesItems.push({
        user_id: userId,
        tvdb_id: seriesTvdbId,
        media_type: "series",
        title: seriesTitle,
        year: null,
        overview: null,
        image_url: null,
        status: getSeriesImportStatus(episodeStats),
        updated_at: episodeStats.lastWatchedAt || normalizeTvtimeDate(show.created_at) || new Date().toISOString()
      });

      episodeStats.watchedEpisodes.forEach(({ season, episode }) => {
        episodeWatches.push({
          user_id: userId,
          series_tvdb_id: seriesTvdbId,
          series_title: seriesTitle,
          episode_tvdb_id: getTvdbId(episode),
          season_number: Number(season.number || 0),
          episode_number: Number(episode.number || 0),
          episode_name: episode.name || null,
          watched_at: normalizeTvtimeDate(episode.watched_at),
          watched_count: Number(episode.watched_count || 1),
          rewatch_count: Number(episode.rewatch_count || 0),
          updated_at: normalizeTvtimeDate(episode.watched_at) || new Date().toISOString()
        });
      });
    });

  return {
    items: uniqueBy([...movieItems, ...seriesItems], (item) => `${item.user_id}:${item.tvdb_id}:${item.media_type}`),
    episodeWatches: uniqueBy(episodeWatches, (episode) => `${episode.user_id}:${episode.series_tvdb_id}:${episode.episode_tvdb_id}`),
    movieCount: movieItems.length,
    seriesCount: seriesItems.length
  };
}

function getSeriesEpisodeStats(show) {
  const watchedEpisodes = [];
  let totalEpisodes = 0;
  let lastWatchedAt = "";

  (show.seasons || []).forEach((season) => {
    (season.episodes || []).forEach((episode) => {
      if (!episode.special) totalEpisodes += 1;
      if (!episode.is_watched || !getTvdbId(episode)) return;

      const watchedAt = normalizeTvtimeDate(episode.watched_at);
      if (watchedAt && (!lastWatchedAt || watchedAt > lastWatchedAt)) lastWatchedAt = watchedAt;
      watchedEpisodes.push({ season, episode });
    });
  });

  return {
    totalEpisodes,
    watchedEpisodes,
    watchedCount: watchedEpisodes.length,
    lastWatchedAt
  };
}

function getSeriesImportStatus({ totalEpisodes, watchedCount }) {
  if (watchedCount > 0 && totalEpisodes > 0 && watchedCount >= totalEpisodes) return "watched";
  if (watchedCount > 0) return "watching";
  return "watchlist";
}

async function upsertInChunks(table, records, onConflict) {
  for (let index = 0; index < records.length; index += TVTIME_IMPORT_CHUNK_SIZE) {
    const chunk = records.slice(index, index + TVTIME_IMPORT_CHUNK_SIZE);
    const { error } = await profileClient
      .from(table)
      .upsert(chunk, { onConflict });

    if (error) throw error;
  }
}

function readJsonFile(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.addEventListener("load", () => {
      try {
        resolve(JSON.parse(String(reader.result || "")));
      } catch (error) {
        reject(new Error(`${file.name} n'est pas un JSON valide.`));
      }
    });
    reader.addEventListener("error", () => reject(new Error(`Lecture impossible: ${file.name}`)));
    reader.readAsText(file);
  });
}

function getTvdbId(item) {
  return item?.id?.tvdb ? String(item.id.tvdb) : "";
}

function normalizeTvtimeDate(value) {
  if (!value) return null;
  const raw = String(value).trim();
  const normalized = raw.includes("T") ? raw : `${raw.replace(" ", "T")}Z`;
  const date = new Date(normalized);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}

function uniqueBy(items, getKey) {
  const seen = new Set();
  return items.filter((item) => {
    const key = getKey(item);
    if (seen.has(key)) return false;

    seen.add(key);
    return true;
  });
}

function setTvtimeImportLoading(isLoading, message = "") {
  if (profileEls.importTvtimeButton) profileEls.importTvtimeButton.disabled = isLoading;
  if (message) setTvtimeImportMessage(message);
}

function setTvtimeImportMessage(message) {
  if (profileEls.tvtimeImportMessage) profileEls.tvtimeImportMessage.textContent = message;
}

async function logoutProfile() {
  if (!profileClient) return;

  await profileClient.auth.signOut();
  window.location.replace("index.html");
}

function populateProfileCountries() {
  if (!profileEls.editCountry) return;

  const countryNames = Intl.DisplayNames
    ? new Intl.DisplayNames(["fr"], { type: "region" })
    : null;

  profileEls.editCountry.innerHTML = "";

  PROFILE_COUNTRY_CODES
    .map((code) => ({
      code,
      label: countryNames?.of(code) || code
    }))
    .sort((a, b) => a.label.localeCompare(b.label, "fr"))
    .forEach((country) => {
      const option = document.createElement("option");
      option.value = country.code;
      option.textContent = `${regionToFlag(country.code)} ${country.label}`;
      profileEls.editCountry.append(option);
    });
}

function regionToFlag(regionCode) {
  return String(regionCode || "FR")
    .toUpperCase()
    .replace(/./g, (char) => String.fromCodePoint(127397 + char.charCodeAt()));
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

function getProfileDisplayName(user) {
  const metadata = user.user_metadata || {};
  return metadata.display_name || metadata.username || user.email?.split("@")[0] || "Utilisateur";
}

async function syncLegacyDisplayName() {
  const user = profileSession?.user;
  const metadata = user?.user_metadata || {};
  const legacyName = normalizeUsername(metadata.username || user?.email?.split("@")[0]);

  if (!profileClient || !user || metadata.display_name || !isValidUsername(legacyName)) return;

  const { data, error } = await profileClient.auth.updateUser({
    data: {
      ...metadata,
      display_name: legacyName
    }
  });

  if (!error && data.user) {
    profileSession = {
      ...profileSession,
      user: data.user
    };
  }
}

async function isUsernameAvailable(username) {
  const { data, error } = await profileClient.rpc("is_streamory_username_available", {
    candidate: username
  });

  if (error) return true;
  return data === true;
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

function posterPlaceholder() {
  return "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='160' height='240' viewBox='0 0 160 240'%3E%3Crect width='160' height='240' fill='%2320242a'/%3E%3Cpath d='M42 72h76v96H42z' fill='none' stroke='%236f7782' stroke-width='6'/%3E%3Cpath d='M55 92h50M55 112h50M55 132h32' stroke='%23a7adb6' stroke-width='6' stroke-linecap='round'/%3E%3C/svg%3E";
}

function formatProfileError(error) {
  const message = error?.message || "Erreur inconnue.";
  const normalizedMessage = message.toLowerCase();

  if (message.includes("New email should be different")) {
    return "Le nouvel email est identique à l'ancien.";
  }

  if (
    normalizedMessage.includes("already registered") ||
    normalizedMessage.includes("already been registered") ||
    (normalizedMessage.includes("email") && normalizedMessage.includes("exists")) ||
    (normalizedMessage.includes("email") && normalizedMessage.includes("taken"))
  ) {
    return "Cet email est déjà utilisé par un autre compte.";
  }

  if (
    normalizedMessage.includes("profiles_username") ||
    (normalizedMessage.includes("duplicate key") && normalizedMessage.includes("username"))
  ) {
    return "Ce nom d'utilisateur est déjà utilisé.";
  }

  if (message.includes("Password should be")) {
    return "Le mot de passe est trop court.";
  }

  if (message.includes("Unable to validate email address")) {
    return "Adresse email invalide.";
  }

  return message;
}

function normalizeTvdbId(value) {
  const text = String(value || "");
  const match = text.match(/\d+/);
  return match ? match[0] : text;
}

function preventPageZoom() {
  document.addEventListener("gesturestart", (event) => event.preventDefault());
  document.addEventListener("gesturechange", (event) => event.preventDefault());
  document.addEventListener("gestureend", (event) => event.preventDefault());
}
