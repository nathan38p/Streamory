const publicEls = {
  publicUsername: document.getElementById("publicUsername"),
  publicCountryFlag: document.getElementById("publicCountryFlag"),
  publicFriendCount: document.getElementById("publicFriendCount"),
  publicProfileMessage: document.getElementById("publicProfileMessage"),
  friendsDialog: document.getElementById("friendsDialog"),
  friendsList: document.getElementById("friendsList"),
  friendSearchInput: document.getElementById("friendSearchInput"),
  friendSearchButton: document.getElementById("friendSearchButton"),
  friendSearchMessage: document.getElementById("friendSearchMessage"),
  friendSearchResults: document.getElementById("friendSearchResults"),
  ownProfileActions: document.getElementById("ownProfileActions"),
  backButton: document.getElementById("backButton"),
  ownProfileButton: document.getElementById("ownProfileButton"),
  notificationsButton: document.getElementById("notificationsButton"),
  notificationsBadge: document.getElementById("notificationsBadge"),
  notificationsDialog: document.getElementById("notificationsDialog"),
  notificationsList: document.getElementById("notificationsList"),
  removeFriendDialog: document.getElementById("removeFriendDialog"),
  removeFriendMessage: document.getElementById("removeFriendMessage"),
  confirmRemoveFriendButton: document.getElementById("confirmRemoveFriendButton")
};

let publicClient = null;
let publicSession = null;
let publicProfile = null;
let publicFriends = [];
let publicNotifications = [];

initPublicProfilePage();

function initPublicProfilePage() {
  preventPageZoom();
  connectPublicSupabase();
  publicEls.confirmRemoveFriendButton?.addEventListener("click", removePublicFriend);
  publicEls.publicFriendCount?.addEventListener("click", () => {
    if (publicEls.publicFriendCount.disabled) return;
    if (isOwnPublicProfile()) {
      renderFriendsList();
      publicEls.friendsDialog?.showModal();
      return;
    }
    handleProfileFriendAction();
  });
  publicEls.friendSearchButton?.addEventListener("click", searchFriends);
  publicEls.friendSearchInput?.addEventListener("keydown", (event) => {
    if (event.key === "Enter") {
      event.preventDefault();
      searchFriends();
    }
  });
  publicEls.ownProfileButton?.addEventListener("click", openOwnProfile);
  publicEls.notificationsButton?.addEventListener("click", () => {
    renderNotifications();
    publicEls.notificationsDialog?.showModal();
  });
}

function getSupabaseConfig() {
  const config = window.CONFIG || {};
  const legacyConfig = window.STREAMORY_CONFIG || {};

  return {
    supabaseUrl: config.SUPABASE_URL || config.supabaseUrl || legacyConfig.supabaseUrl || "",
    supabaseAnonKey: config.SUPABASE_ANON_KEY || config.supabaseAnonKey || legacyConfig.supabaseAnonKey || ""
  };
}

async function connectPublicSupabase() {
  const { supabaseUrl, supabaseAnonKey } = getSupabaseConfig();

  if (!window.supabase || !supabaseUrl || !supabaseAnonKey) {
    setPublicMessage("Connexion Supabase impossible.");
    return;
  }

  publicClient = window.supabase.createClient(supabaseUrl, supabaseAnonKey);
  const { data } = await publicClient.auth.getSession();
  publicSession = data.session;
  if (publicSession) loadFriendNotifications();

  await loadPublicProfile();
}

async function loadPublicProfile() {
  const username = normalizeUsername(new URLSearchParams(window.location.search).get("u"));

  if (!isValidUsername(username)) {
    setPublicMessage("Profil introuvable.");
    return;
  }

  const { data, error } = await publicClient.rpc("get_streamory_public_profile", {
    profile_username: username
  });

  if (error) {
    setPublicMessage(formatPublicProfileError(error));
    return;
  }

  if (!data?.length) {
    setPublicMessage("Profil introuvable.");
    return;
  }

  publicProfile = data[0];
  renderPublicProfile();
}

function renderPublicProfile() {
  const friendCount = Number(publicProfile.friend_count || 0);
  publicEls.publicUsername.textContent = publicProfile.username;
  publicEls.publicCountryFlag.textContent = publicProfile.country ? regionToFlag(publicProfile.country) : "";

  publicEls.ownProfileActions.hidden = !publicSession;
  publicEls.backButton.hidden = Boolean(publicSession);
  renderOwnProfileButton();

  if (!publicSession) {
    publicEls.publicFriendCount.textContent = "Connecte-toi";
    publicEls.publicFriendCount.disabled = false;
    return;
  }

  if (isOwnPublicProfile()) {
    publicEls.publicFriendCount.textContent = `${friendCount} ami${friendCount > 1 ? "s" : ""}`;
    publicEls.publicFriendCount.disabled = false;
    setPublicMessage("");
    loadOwnFriends();
    return;
  }

  if (publicProfile.relationship_status === "accepted") {
    publicEls.publicFriendCount.textContent = "✓ Ami";
    publicEls.publicFriendCount.disabled = false;
    return;
  }

  if (publicProfile.relationship_status === "pending") {
    publicEls.publicFriendCount.textContent = "Demande envoyée";
    publicEls.publicFriendCount.disabled = true;
    return;
  }

  publicEls.publicFriendCount.textContent = "+ Ajouter";
  publicEls.publicFriendCount.disabled = false;
}

function isOwnPublicProfile() {
  return Boolean(publicSession?.user?.id && publicProfile?.user_id === publicSession.user.id);
}

function renderOwnProfileButton() {
  if (!publicEls.ownProfileButton) return;

  const isOwnProfile = isOwnPublicProfile();
  publicEls.ownProfileButton.textContent = isOwnProfile ? "⚙️" : "👤";
  publicEls.ownProfileButton.setAttribute("aria-label", isOwnProfile ? "Réglages" : "Mon profil");
  publicEls.ownProfileButton.title = isOwnProfile ? "Réglages" : "Mon profil";
}

async function loadOwnFriends() {
  if (!publicClient || !publicSession) return;

  const { data, error } = await publicClient.rpc("list_streamory_friends");
  publicFriends = error ? [] : data || [];
  renderFriendsList();
}

function renderFriendsList() {
  if (!publicEls.friendsList) return;

  publicEls.friendsList.innerHTML = "";

  if (!publicFriends.length) {
    publicEls.friendsList.append(emptySocialMessage("Aucun ami pour le moment."));
    return;
  }

  publicFriends.forEach((friend) => {
    publicEls.friendsList.append(createSocialItem({
      username: friend.username,
      country: friend.country,
      meta: "Ami",
      actions: [
        { label: "Profil", onClick: () => openPublicProfile(friend.username) }
      ]
    }));
  });
}

function openPublicProfile(username) {
  window.location.href = `user.html?u=${encodeURIComponent(normalizeUsername(username))}`;
}

async function searchFriends() {
  if (!publicClient || !publicSession || !publicEls.friendSearchInput || !publicEls.friendSearchResults) return;

  const query = publicEls.friendSearchInput.value.trim();
  publicEls.friendSearchResults.innerHTML = "";
  publicEls.friendSearchMessage.textContent = "";

  if (query.length < 2) {
    publicEls.friendSearchMessage.textContent = "Entre au moins 2 caractères.";
    return;
  }

  const { data, error } = await publicClient.rpc("search_streamory_profiles", {
    candidate: query
  });

  if (error) {
    publicEls.friendSearchMessage.textContent = "Recherche impossible.";
    return;
  }

  if (!data?.length) {
    publicEls.friendSearchResults.append(emptySocialMessage("Aucun utilisateur trouvé."));
    return;
  }

  data.forEach((user) => {
    const actions = [];

    if (user.relationship_status === "accepted") {
      actions.push({ label: "Profil", onClick: () => openPublicProfile(user.username) });
    } else if (user.relationship_status === "pending") {
      actions.push({ label: "Demande envoyée", disabled: true, onClick: () => {} });
    } else {
      actions.push({ label: "Ajouter", onClick: () => sendFriendRequest(user.user_id) });
    }

    publicEls.friendSearchResults.append(createSocialItem({
      username: user.username,
      country: user.country,
      meta: user.relationship_status === "accepted" ? "Ami" : "",
      actions
    }));
  });
}

async function sendFriendRequest(userId) {
  const { error } = await publicClient.rpc("send_streamory_friend_request", {
    target_user_id: userId
  });

  if (error) {
    publicEls.friendSearchMessage.textContent = "Demande impossible.";
    return;
  }

  publicEls.friendSearchMessage.textContent = "Demande envoyée.";
  await searchFriends();
}

function handleProfileFriendAction() {
  if (!publicProfile) return;

  if (!publicSession) {
    setPublicMessage("Connecte-toi pour ajouter cet utilisateur.");
    return;
  }

  if (publicProfile.relationship_status === "accepted") {
    if (publicEls.removeFriendMessage) {
      publicEls.removeFriendMessage.textContent = `Retirer ${publicProfile.username} de tes amis ?`;
    }
    publicEls.removeFriendDialog?.showModal();
    return;
  }

  sendPublicFriendRequest();
}

async function removePublicFriend() {
  if (!publicClient || !publicProfile) return;

  const { error } = await publicClient.rpc("remove_streamory_friend", {
    target_user_id: publicProfile.user_id
  });

  if (error) {
    setPublicMessage("Suppression impossible.");
    return;
  }

  publicEls.removeFriendDialog?.close();
  setPublicMessage("");
  await loadPublicProfile();
}

function openOwnProfile() {
  if (!publicSession) return;

  if (isOwnPublicProfile()) {
    window.location.href = "profile.html?settings=1";
    return;
  }

  const metadata = publicSession.user.user_metadata || {};
  const username = normalizeUsername(metadata.display_name || metadata.username || publicSession.user.email?.split("@")[0]);

  if (!isValidUsername(username)) {
    window.location.href = "profile.html";
    return;
  }

  openPublicProfile(username);
}

async function loadFriendNotifications() {
  if (!publicClient || !publicSession) return;

  const { data, error } = await publicClient.rpc("list_streamory_friend_notifications");
  publicNotifications = error ? [] : data || [];
  renderNotificationBadge();
  renderNotifications();
}

function renderNotificationBadge() {
  const count = publicNotifications.length;
  if (publicEls.notificationsButton) publicEls.notificationsButton.hidden = count === 0;
  if (publicEls.notificationsBadge) {
    publicEls.notificationsBadge.hidden = count === 0;
    publicEls.notificationsBadge.textContent = String(count);
  }
}

function renderNotifications() {
  if (!publicEls.notificationsList) return;

  publicEls.notificationsList.innerHTML = "";

  if (!publicNotifications.length) {
    publicEls.notificationsList.append(emptySocialMessage("Aucune notification."));
    return;
  }

  publicNotifications.forEach((notification) => {
    publicEls.notificationsList.append(createSocialItem({
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

  await publicClient.rpc(functionName, { request_id: requestId });
  await loadFriendNotifications();
  await loadPublicProfile();
}

async function sendPublicFriendRequest() {
  if (!publicClient || !publicProfile) return;

  if (!publicSession) {
    window.location.href = "index.html";
    return;
  }

  const { error } = await publicClient.rpc("send_streamory_friend_request", {
    target_user_id: publicProfile.user_id
  });

  if (error) {
    setPublicMessage("Demande impossible.");
    return;
  }

  setPublicMessage("Demande envoyée.");
  await loadPublicProfile();
}

function setPublicMessage(message) {
  if (publicEls.publicProfileMessage) publicEls.publicProfileMessage.textContent = message;
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

function formatPublicProfileError(error) {
  const message = error?.message || "";

  if (message.includes("get_streamory_public_profile")) {
    return "Profil public pas encore activé dans Supabase. Ré-exécute supabase/schema.sql.";
  }

  return "Chargement du profil impossible.";
}

function normalizeUsername(value) {
  return String(value || "").toLowerCase().replace(/[^a-z0-9._-]/g, "").slice(0, 28);
}

function isValidUsername(username) {
  return /^[a-z0-9._-]{3,28}$/.test(username);
}

function regionToFlag(regionCode) {
  return String(regionCode || "FR")
    .toUpperCase()
    .replace(/./g, (char) => String.fromCodePoint(127397 + char.charCodeAt()));
}

function preventPageZoom() {
  document.addEventListener("gesturestart", (event) => event.preventDefault());
  document.addEventListener("gesturechange", (event) => event.preventDefault());
  document.addEventListener("gestureend", (event) => event.preventDefault());
}
