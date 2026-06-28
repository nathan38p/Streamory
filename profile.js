

const profileEls = {
  profileUsername: document.getElementById("profileUsername"),
  profilePublicHandle: document.getElementById("profilePublicHandle"),
  profileCountryFlag: document.getElementById("profileCountryFlag"),
  settingsButton: document.getElementById("settingsButton"),
  settingsDialog: document.getElementById("settingsDialog"),
  friendsButton: document.getElementById("friendsButton"),
  shareProfileButton: document.getElementById("shareProfileButton"),
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
  editUsername: document.getElementById("editUsername"),
  editCountry: document.getElementById("editCountry"),
  editEmail: document.getElementById("editEmail"),
  editPassword: document.getElementById("editPassword"),
  saveProfileButton: document.getElementById("saveProfileButton"),
  logoutButton: document.getElementById("logoutButton")
};

const PROFILE_COUNTRY_CODES = ["FR", "BE", "CH", "CA", "US", "GB", "ES", "IT", "DE", "PT"];

let profileClient = null;
let profileSession = null;
let profileFriends = [];
let profileNotifications = [];

initProfilePage();

function initProfilePage() {
  preventPageZoom();
  populateProfileCountries();
  bindProfileEvents();
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

  profileClient.auth.onAuthStateChange((_event, session) => {
    profileSession = session;

    if (!profileSession) {
      window.location.replace("index.html");
      return;
    }

    renderProfile();
    syncLegacyDisplayName();
    loadProfileSocialData();
  });
}

function bindProfileEvents() {
  profileEls.settingsButton?.addEventListener("click", () => {
    fillSettingsForm();
    profileEls.settingsDialog?.showModal();
  });

  profileEls.friendsButton?.addEventListener("click", () => {
    renderFriendsList();
    profileEls.friendsDialog?.showModal();
  });
  profileEls.shareProfileButton?.addEventListener("click", sharePublicProfile);

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
  profileEls.logoutButton?.addEventListener("click", logoutProfile);
}

function renderProfile() {
  const user = profileSession?.user;
  if (!user) return;

  const metadata = user.user_metadata || {};
  const username = getProfileDisplayName(user);
  const country = metadata.country || "FR";

  if (profileEls.profileUsername) profileEls.profileUsername.textContent = username;
  if (profileEls.profilePublicHandle) profileEls.profilePublicHandle.textContent = `@${normalizeUsername(username)}`;
  if (profileEls.profileCountryFlag) profileEls.profileCountryFlag.textContent = regionToFlag(country);
}

function getPublicProfileUrl(username = getCurrentPublicUsername()) {
  const url = new URL("user.html", window.location.href);
  url.searchParams.set("u", normalizeUsername(username));
  return url.href;
}

function getCurrentPublicUsername() {
  return normalizeUsername(getProfileDisplayName(profileSession?.user || {}));
}

function openPublicProfile(username) {
  window.location.href = getPublicProfileUrl(username);
}

async function sharePublicProfile() {
  const url = getPublicProfileUrl();

  if (navigator.share) {
    await navigator.share({
      title: "Mon profil Streamory",
      text: "Voici mon profil Streamory.",
      url
    });
    return;
  }

  if (navigator.clipboard) {
    await navigator.clipboard.writeText(url);
    alert("Lien du profil copié.");
    return;
  }

  window.prompt("Lien du profil", url);
}

async function loadProfileSocialData() {
  if (!profileClient || !profileSession?.user) return;

  await Promise.all([
    loadFriends(),
    loadNotifications()
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
  if (!profileEls.notificationsBadge) return;

  const count = profileNotifications.length;
  profileEls.notificationsBadge.hidden = count === 0;
  profileEls.notificationsBadge.textContent = String(count);
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
  if (profileEls.editPassword) profileEls.editPassword.value = "";
}

async function saveProfile() {
  if (!profileClient || !profileSession?.user) return;

  const currentUser = profileSession.user;
  const currentMetadata = currentUser.user_metadata || {};

  const username = normalizeUsername(profileEls.editUsername?.value || "");
  const country = profileEls.editCountry?.value || "FR";
  const email = profileEls.editEmail?.value.trim() || currentUser.email;
  const password = profileEls.editPassword?.value || "";
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

  if (password.length > 0) {
    if (password.length < 6) {
      alert("Le mot de passe doit contenir au moins 6 caractères.");
      return;
    }

    updatePayload.password = password;
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

function preventPageZoom() {
  document.addEventListener("gesturestart", (event) => event.preventDefault());
  document.addEventListener("gesturechange", (event) => event.preventDefault());
  document.addEventListener("gestureend", (event) => event.preventDefault());
}
