const TVDB_API_BASE = "https://api4.thetvdb.com/v4";
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type"
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const apiKey = Deno.env.get("TVDB_API_KEY");
    const pin = Deno.env.get("TVDB_PIN");
    if (!apiKey) throw new Error("TVDB_API_KEY is missing");

    const url = new URL(request.url);
    const query = url.searchParams.get("q")?.trim();
    const type = url.searchParams.get("type") || "series";
    if (!query) throw new Error("Missing q parameter");

    const token = await getTvdbToken(apiKey, pin);
    const searchUrl = new URL(`${TVDB_API_BASE}/search`);
    searchUrl.searchParams.set("query", query);
    searchUrl.searchParams.set("type", type);

    const tvdbResponse = await fetch(searchUrl, {
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: "application/json"
      }
    });

    const payload = await tvdbResponse.json();
    return json(payload, tvdbResponse.status);
  } catch (error) {
    return json({ error: error.message }, 400);
  }
});

async function getTvdbToken(apiKey: string, pin?: string | null) {
  const response = await fetch(`${TVDB_API_BASE}/login`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Accept: "application/json" },
    body: JSON.stringify({ apikey: apiKey, pin })
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
