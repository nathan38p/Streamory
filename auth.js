

const authEls = {
  loginForm: document.getElementById("loginForm"),
  signupForm: document.getElementById("signupForm"),
  showLoginButton: document.getElementById("showLoginButton"),
  showSignupButton: document.getElementById("showSignupButton"),
  loginEmailInput: document.getElementById("loginEmailInput"),
  loginPasswordInput: document.getElementById("loginPasswordInput"),
  signupEmailInput: document.getElementById("signupEmailInput"),
  signupPasswordInput: document.getElementById("signupPasswordInput"),
  confirmPasswordInput: document.getElementById("confirmPasswordInput"),
  usernameInput: document.getElementById("usernameInput"),
  birthDateInput: document.getElementById("birthDateInput"),
  countryInput: document.getElementById("countryInput"),
  loginButton: document.getElementById("loginButton"),
  signupButton: document.getElementById("signupButton"),
  loginMessage: document.getElementById("loginMessage"),
  signupMessage: document.getElementById("signupMessage")
};

const COUNTRY_CODES = ["FR", "BE", "CH", "CA", "US", "GB", "ES", "IT", "DE", "PT"];

let authClient = null;

initAuthPage();

function initAuthPage() {
  preventPageZoom();
  populateCountries();
  bindAuthEvents();
  connectAuthSupabase();
}

function getSupabaseConfig() {
  const config = window.CONFIG || {};
  const legacyConfig = window.STREAMORY_CONFIG || {};

  return {
    supabaseUrl: config.SUPABASE_URL || config.supabaseUrl || legacyConfig.supabaseUrl || "",
    supabaseAnonKey: config.SUPABASE_ANON_KEY || config.supabaseAnonKey || legacyConfig.supabaseAnonKey || ""
  };
}

async function connectAuthSupabase() {
  const { supabaseUrl, supabaseAnonKey } = getSupabaseConfig();

  if (!window.supabase || !supabaseUrl || !supabaseAnonKey) {
    setLoginMessage("Configure Supabase dans config.js avant la connexion.");
    return;
  }

  authClient = window.supabase.createClient(supabaseUrl, supabaseAnonKey);
  const { data } = await authClient.auth.getSession();

  if (data.session) {
    window.location.replace("app.html");
  }
}

function bindAuthEvents() {
  authEls.showLoginButton?.addEventListener("click", () => setAuthMode("login"));
  authEls.showSignupButton?.addEventListener("click", () => setAuthMode("signup"));
  authEls.loginForm?.addEventListener("submit", handleLogin);
  authEls.signupForm?.addEventListener("submit", handleSignup);
  authEls.birthDateInput?.addEventListener("input", formatBirthDateInput);
  authEls.birthDateInput?.addEventListener("keydown", handleBirthDateSlash);
}

function setAuthMode(mode) {
  const isLogin = mode === "login";

  authEls.loginForm.hidden = !isLogin;
  authEls.signupForm.hidden = isLogin;
  authEls.showLoginButton.classList.toggle("active", isLogin);
  authEls.showSignupButton.classList.toggle("active", !isLogin);
  setLoginMessage("");
  setSignupMessage("");
}

async function handleLogin(event) {
  event.preventDefault();

  if (!authClient) {
    setLoginMessage("Configure Supabase dans config.js avant la connexion.");
    return;
  }

  setAuthLoading("login", true);

  try {
    const { error } = await authClient.auth.signInWithPassword({
      email: authEls.loginEmailInput.value.trim(),
      password: authEls.loginPasswordInput.value
    });

    if (error) {
      setLoginMessage(formatAuthError(error));
      return;
    }

    window.location.replace("app.html");
  } finally {
    setAuthLoading("login", false);
  }
}

async function handleSignup(event) {
  event.preventDefault();

  if (!authClient) {
    setSignupMessage("Configure Supabase dans config.js avant l'inscription.");
    return;
  }

  const email = authEls.signupEmailInput.value.trim();
  const password = authEls.signupPasswordInput.value;
  const confirmPassword = authEls.confirmPasswordInput.value;
  const username = authEls.usernameInput.value.trim();
  const birthDate = authEls.birthDateInput.value.trim();
  const country = authEls.countryInput.value;

  if (password !== confirmPassword) {
    setSignupMessage("Les mots de passe ne correspondent pas.");
    return;
  }

  setAuthLoading("signup", true);

  try {
    const { error } = await authClient.auth.signUp({
      email,
      password,
      options: {
        data: {
          username,
          birth_date: birthDate,
          country
        }
      }
    });

    if (error) {
      setSignupMessage(formatAuthError(error));
      return;
    }

    setSignupMessage("Compte créé. Tu peux maintenant te connecter.");
    authEls.signupForm.reset();
    authEls.countryInput.value = "FR";
    setAuthMode("login");
  } finally {
    setAuthLoading("signup", false);
  }
}

function setAuthLoading(mode, isLoading) {
  const button = mode === "login" ? authEls.loginButton : authEls.signupButton;
  if (button) button.disabled = isLoading;
}

function setLoginMessage(message) {
  if (authEls.loginMessage) authEls.loginMessage.textContent = message;
}

function setSignupMessage(message) {
  if (authEls.signupMessage) authEls.signupMessage.textContent = message;
}

function populateCountries() {
  if (!authEls.countryInput) return;

  const countryNames = Intl.DisplayNames
    ? new Intl.DisplayNames(["fr"], { type: "region" })
    : null;

  COUNTRY_CODES
    .map((code) => ({
      code,
      label: countryNames?.of(code) || code
    }))
    .sort((a, b) => a.label.localeCompare(b.label, "fr"))
    .forEach((country) => {
      const option = document.createElement("option");
      option.value = country.code;
      option.textContent = `${regionToFlag(country.code)} ${country.label}`;
      authEls.countryInput.append(option);
    });

  authEls.countryInput.value = "FR";
}

function regionToFlag(regionCode) {
  return regionCode
    .toUpperCase()
    .replace(/./g, (char) => String.fromCodePoint(127397 + char.charCodeAt()));
}

function formatBirthDateInput() {
  const digits = authEls.birthDateInput.value.replace(/\D/g, "").slice(0, 8);
  const parts = [];

  if (digits.length > 0) parts.push(digits.slice(0, 2));
  if (digits.length > 2) parts.push(digits.slice(2, 4));
  if (digits.length > 4) parts.push(digits.slice(4, 8));

  authEls.birthDateInput.value = parts.join("/");
}

function handleBirthDateSlash(event) {
  if (event.key !== "/") return;
  event.preventDefault();
  formatBirthDateInput();
}

function formatAuthError(error) {
  const message = error?.message || "Erreur inconnue.";

  if (message.includes("Invalid login credentials")) {
    return "Email ou mot de passe incorrect.";
  }

  if (message.includes("User already registered")) {
    return "Un compte existe déjà avec cet email.";
  }

  if (message.includes("Password should be")) {
    return "Le mot de passe est trop court.";
  }

  return message;
}

function preventPageZoom() {
  document.addEventListener("gesturestart", (event) => event.preventDefault());
  document.addEventListener("gesturechange", (event) => event.preventDefault());
  document.addEventListener("gestureend", (event) => event.preventDefault());
}