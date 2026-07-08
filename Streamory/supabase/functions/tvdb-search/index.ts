const TVDB_API_BASE = "https://api4.thetvdb.com/v4";
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type"
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const body = await readJsonBody(request);

  try {
    const apiKey = Deno.env.get("TVDB_API_KEY");
    const pin = Deno.env.get("TVDB_PIN");
    if (!apiKey) throw new Error("TVDB_API_KEY is missing");

    const url = new URL(request.url);
    const query = (body.q || url.searchParams.get("q") || "").trim();
    const type = (body.type || url.searchParams.get("type") || "").trim();
    const language = (body.language || url.searchParams.get("language") || "").trim();
    const endpoint = (body.endpoint || url.searchParams.get("endpoint") || "").trim();

    const token = await getTvdbToken(apiKey, pin);

    if (endpoint) {
      return json(await fetchTvdbEndpoint({ token, endpoint }));
    }

    if (!query) throw new Error("Missing q parameter");

    const languages = uniqueLanguages([language, "eng", ""]);
    const payloads = [];

    for (const searchLanguage of languages) {
      const payload = await searchTvdb({ token, query, type, language: searchLanguage });
      payloads.push(payload);
      if (Array.isArray(payload.data) && payload.data.length > 0 && searchLanguage !== language) break;
    }

    const [firstPayload] = payloads;
    return json({
      ...firstPayload,
      data: mergeTvdbResults(payloads)
    });
  } catch (error) {
    return json({ error: getErrorMessage(error) }, 400);
  }
});

async function readJsonBody(request: Request) {
  if (request.method === "GET") return {} as Record<string, string>;

  try {
    const body = await request.json();
    if (!body || typeof body !== "object") return {} as Record<string, string>;
    return body as Record<string, string>;
  } catch (_error) {
    return {} as Record<string, string>;
  }
}

async function fetchTvdbEndpoint({
  token,
  endpoint
}: {
  token: string;
  endpoint: string;
}) {
  const cleanEndpoint = normalizeTvdbEndpoint(endpoint);
  if (!cleanEndpoint) {
    throw new Error("Unsupported TheTVDB endpoint");
  }

  const tvdbResponse = await fetch(`${TVDB_API_BASE}/${cleanEndpoint}`, {
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: "application/json"
    }
  });

  const payload = await tvdbResponse.json();
  if (!tvdbResponse.ok) {
    throw new Error(payload.message || "TheTVDB endpoint failed");
  }

  return payload;
}

function normalizeTvdbEndpoint(endpoint: string) {
  const cleanEndpoint = getTvdbEndpointPath(endpoint);
  const [rawPath, rawQuery = ""] = cleanEndpoint.split("?");
  const parts = rawPath.split("/").filter(Boolean);
  if (parts[0] === "v4") parts.shift();

  const query = new URLSearchParams(rawQuery);

  if ((parts[0] === "series" || parts[0] === "movies") && (parts.length === 2 || parts.length === 3)) {
    const id = getDigits(parts[1]);
    if (!id) return null;
    if (parts.length === 3 && parts[2] !== "extended") return null;
    if (!hasOnlyQuery(query, "meta", "translations")) return null;

    const path = `${parts[0]}/${id}${parts[2] === "extended" ? "/extended" : ""}`;
    return appendQuery(path, query);
  }

  if ((parts[0] === "series" || parts[0] === "movies") && parts[2] === "artworks" && parts.length >= 3 && parts.length <= 4) {
    const id = getDigits(parts[1]);
    const artworkType = parts[3];
    if (!id) return null;
    if (artworkType && !/^[a-z-]+$/.test(artworkType)) return null;
    if (!hasOnlyQuery(query, "page", /^\d+$/)) return null;

    const path = `${parts[0]}/${id}/artworks${artworkType ? `/${artworkType}` : ""}`;
    return appendQuery(path, query);
  }

  if (parts[0] === "series" && parts[2] === "episodes" && parts.length >= 4 && parts.length <= 5) {
    const id = getDigits(parts[1]);
    const episodeType = parts[3];
    const language = parts[4];
    if (!id || !/^[a-z-]+$/.test(episodeType)) return null;
    if (language && !/^[a-z]{3}$/.test(language)) return null;
    if (!hasOnlyQuery(query, "page", /^\d+$/)) return null;

    const path = `series/${id}/episodes/${episodeType}${language ? `/${language}` : ""}`;
    return appendQuery(path, query);
  }

  return null;
}

function getTvdbEndpointPath(endpoint: string) {
  const trimmedEndpoint = endpoint.trim();

  try {
    const url = new URL(trimmedEndpoint);
    if (url.origin !== "https://api4.thetvdb.com") return "";
    return `${url.pathname}${url.search}`.replace(/^\/+/, "");
  } catch (_error) {
    return trimmedEndpoint.replace(/^\/+/, "");
  }
}

function getDigits(value: string | undefined) {
  return String(value || "").replace(/\D/g, "");
}

function hasOnlyQuery(query: URLSearchParams, key: string, expectedValue: string | RegExp) {
  const keys = [...query.keys()];
  if (keys.length === 0) return true;
  if (keys.length !== 1 || keys[0] !== key) return false;

  const value = query.get(key) || "";
  return typeof expectedValue === "string" ? value === expectedValue : expectedValue.test(value);
}

function appendQuery(path: string, query: URLSearchParams) {
  const queryString = query.toString();
  return queryString ? `${path}?${queryString}` : path;
}

async function searchTvdb({
  token,
  query,
  type,
  language
}: {
  token: string;
  query: string;
  type?: string;
  language?: string;
}) {
  const searchUrl = new URL(`${TVDB_API_BASE}/search`);
  searchUrl.searchParams.set("query", query);
  if (type) searchUrl.searchParams.set("type", type);
  if (language) searchUrl.searchParams.set("language", language);

  const tvdbResponse = await fetch(searchUrl, {
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: "application/json"
    }
  });

  const payload = await tvdbResponse.json();
  if (!tvdbResponse.ok) {
    throw new Error(payload.message || "TheTVDB search failed");
  }

  return payload;
}

function uniqueLanguages(languages: Array<string | undefined>) {
  return languages.filter((language, index, list) => {
    return language !== undefined && list.indexOf(language) === index;
  }) as string[];
}

function mergeTvdbResults(payloads: Array<{ data?: unknown[] }>) {
  const seen = new Set<string>();
  const results: unknown[] = [];

  payloads.forEach((payload) => {
    if (!Array.isArray(payload.data)) return;

    payload.data.forEach((item) => {
      const key = getTvdbResultKey(item);
      if (seen.has(key)) return;

      seen.add(key);
      results.push(item);
    });
  });

  return results;
}

function getTvdbResultKey(item: unknown) {
  if (!item || typeof item !== "object") return JSON.stringify(item);

  const result = item as { id?: unknown; tvdb_id?: unknown; type?: unknown; name?: unknown; title?: unknown };
  return [
    result.type || "",
    result.tvdb_id || result.id || result.name || result.title || JSON.stringify(result)
  ].join(":");
}

function getErrorMessage(error: unknown) {
  return error instanceof Error ? error.message : "Erreur inconnue.";
}

async function getTvdbToken(apiKey: string, pin?: string | null) {
  const credentials: { apikey: string; pin?: string } = { apikey: apiKey };
  if (pin) credentials.pin = pin;

  const response = await fetch(`${TVDB_API_BASE}/login`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Accept: "application/json" },
    body: JSON.stringify(credentials)
  });

  const payload = await response.json();
  if (!response.ok || !payload.data?.token) {
    throw new Error(payload.message || "TheTVDB login failed");
  }

  return payload.data.token;
}

function json(payload: unknown, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json"
    }
  });
}
