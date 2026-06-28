const publicEls = {
  publicUsername: document.getElementById("publicUsername"),
  publicCountryFlag: document.getElementById("publicCountryFlag"),
  publicFriendCount: document.getElementById("publicFriendCount"),
  addFriendButton: document.getElementById("addFriendButton"),
  publicProfileMessage: document.getElementById("publicProfileMessage")
};

let publicClient = null;
let publicSession = null;
let publicProfile = null;

initPublicProfilePage();

function initPublicProfilePage() {
  preventPageZoom();
  connectPublicSupabase();
  publicEls.addFriendButton?.addEventListener("click", sendPublicFriendRequest);
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
  publicEls.publicFriendCount.textContent = `${friendCount} ami${friendCount > 1 ? "s" : ""}`;

  const currentUserId = publicSession?.user?.id;
  const isOwnProfile = currentUserId && currentUserId === publicProfile.user_id;

  if (!publicSession) {
    publicEls.addFriendButton.hidden = false;
    publicEls.addFriendButton.textContent = "Connecte-toi pour ajouter";
    publicEls.addFriendButton.disabled = false;
    return;
  }

  if (isOwnProfile) {
    publicEls.addFriendButton.hidden = true;
    setPublicMessage("C'est ton profil public.");
    return;
  }

  publicEls.addFriendButton.hidden = false;

  if (publicProfile.relationship_status === "accepted") {
    publicEls.addFriendButton.textContent = "Déjà ami";
    publicEls.addFriendButton.disabled = true;
    return;
  }

  if (publicProfile.relationship_status === "pending") {
    publicEls.addFriendButton.textContent = "Demande envoyée";
    publicEls.addFriendButton.disabled = true;
    return;
  }

  publicEls.addFriendButton.textContent = "Ajouter en ami";
  publicEls.addFriendButton.disabled = false;
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
