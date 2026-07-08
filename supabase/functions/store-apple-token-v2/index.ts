import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";
import { SignJWT, importPKCS8 } from "https://esm.sh/jose@5.9.6";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function getRequiredEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) {
    throw new Error(`Missing environment variable: ${name}`);
  }
  return value;
}

async function createAppleClientSecret(): Promise<string> {
  const teamId = getRequiredEnv("APPLE_TEAM_ID");
  const keyId = getRequiredEnv("APPLE_KEY_ID");
  const clientId = getRequiredEnv("APPLE_CLIENT_ID");
  const privateKey = getRequiredEnv("APPLE_PRIVATE_KEY").replace(/\\n/g, "\n");

  const key = await importPKCS8(privateKey, "ES256");
  const now = Math.floor(Date.now() / 1000);

  return await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: keyId })
    .setIssuer(teamId)
    .setIssuedAt(now)
    .setExpirationTime(now + 60 * 60 * 24 * 180)
    .setAudience("https://appleid.apple.com")
    .setSubject(clientId)
    .sign(key);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  try {
    const authorizationHeader = req.headers.get("Authorization") ?? "";
    const jwt = authorizationHeader.replace(/^Bearer\s+/i, "").trim();

    if (!jwt) {
      return jsonResponse({ error: "Missing Supabase JWT" }, 401);
    }

    const payload = await req.json().catch(() => ({}));
    const authorizationCode = payload.authorizationCode ?? payload.authorization_code;

    console.log("store-apple-token payload", {
      hasAuthorizationCode: typeof authorizationCode === "string" && authorizationCode.length > 0,
      authorizationCodeLength: typeof authorizationCode === "string" ? authorizationCode.length : 0,
    });

    if (!authorizationCode || typeof authorizationCode !== "string") {
      return jsonResponse({ error: "Missing authorizationCode" }, 400);
    }

    const supabaseUrl = getRequiredEnv("SUPABASE_URL");
    const serviceRoleKey = getRequiredEnv("SUPABASE_SERVICE_ROLE_KEY");

    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false },
    });

    const {
      data: { user },
      error: userError,
    } = await adminClient.auth.getUser(jwt);

    console.log("store-apple-token user lookup", {
      hasUser: Boolean(user),
      userId: user?.id,
      userError: userError?.message,
    });

    if (userError || !user) {
      return jsonResponse(
        {
          error: "Invalid Supabase JWT",
          details: userError?.message,
        },
        401,
      );
    }

    const clientSecret = await createAppleClientSecret();
    const clientId = getRequiredEnv("APPLE_CLIENT_ID");

    const tokenResponse = await fetch("https://appleid.apple.com/auth/token", {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: new URLSearchParams({
        client_id: clientId,
        client_secret: clientSecret,
        code: authorizationCode,
        grant_type: "authorization_code",
      }),
    });

    const tokenBody = await tokenResponse.json().catch(() => ({}));

    console.log("Apple token exchange response", {
      ok: tokenResponse.ok,
      status: tokenResponse.status,
      hasRefreshToken: typeof tokenBody.refresh_token === "string" && tokenBody.refresh_token.length > 0,
      error: tokenBody.error,
      errorDescription: tokenBody.error_description,
    });

    if (!tokenResponse.ok) {
      return jsonResponse(
        {
          error: "Apple token exchange failed",
          details: tokenBody,
        },
        400,
      );
    }

    const refreshToken = tokenBody.refresh_token;

    if (!refreshToken || typeof refreshToken !== "string") {
      return jsonResponse(
        {
          error: "Apple did not return a refresh_token",
          details: tokenBody,
        },
        400,
      );
    }

    const { error: upsertError } = await adminClient.rpc("store_apple_refresh_token", {
      p_user_id: user.id,
      p_refresh_token: refreshToken,
    });

    if (upsertError) {
      return jsonResponse(
        {
          error: "Could not store Apple refresh_token",
          details: upsertError.message,
        },
        500,
      );
    }

    return jsonResponse({ ok: true, stored_user_id: user.id });
  } catch (error) {
    console.error("store-apple-token failed", error);
    return jsonResponse(
      {
        error: "Unexpected error",
        details: error instanceof Error ? error.message : String(error),
      },
      500,
    );
  }
});
