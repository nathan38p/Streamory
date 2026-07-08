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

    const supabaseUrl = getRequiredEnv("SUPABASE_URL");
    const serviceRoleKey = getRequiredEnv("SUPABASE_SERVICE_ROLE_KEY");

    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false },
    });

    const {
      data: { user },
      error: userError,
    } = await adminClient.auth.getUser(jwt);

    if (userError || !user) {
      return jsonResponse(
        {
          error: "Invalid Supabase JWT",
          details: userError?.message,
        },
        401,
      );
    }

    const { data: refreshToken, error: tokenError } = await adminClient.rpc("get_apple_refresh_token", {
      p_user_id: user.id,
    });

    if (tokenError) {
      return jsonResponse(
        {
          error: "Could not read Apple refresh_token",
          details: tokenError.message,
        },
        500,
      );
    }

    if (refreshToken && typeof refreshToken === "string") {
      const clientSecret = await createAppleClientSecret();
      const clientId = getRequiredEnv("APPLE_CLIENT_ID");

      const revokeResponse = await fetch("https://appleid.apple.com/auth/revoke", {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: new URLSearchParams({
          client_id: clientId,
          client_secret: clientSecret,
          token: refreshToken,
          token_type_hint: "refresh_token",
        }),
      });

      if (!revokeResponse.ok) {
        const details = await revokeResponse.text().catch(() => "");
        console.error("Apple token revocation failed", details);
      }
    }

    const { error: deleteTokenError } = await adminClient.rpc("delete_apple_refresh_token", {
      p_user_id: user.id,
    });

    if (deleteTokenError) {
      return jsonResponse(
        {
          error: "Could not delete stored Apple token",
          details: deleteTokenError.message,
        },
        500,
      );
    }

    const tablesToDeleteByUserId = [
      "user_episode_watches",
      "user_items",
    ];

    for (const tableName of tablesToDeleteByUserId) {
      const { error: deleteTableError } = await adminClient
        .from(tableName)
        .delete()
        .eq("user_id", user.id);

      if (deleteTableError) {
        return jsonResponse(
          {
            error: `Could not delete ${tableName}`,
            details: deleteTableError.message,
          },
          500,
        );
      }
    }

    const { error: deleteFriendRequestsError } = await adminClient
      .from("friend_requests")
      .delete()
      .or(`requester_id.eq.${user.id},addressee_id.eq.${user.id}`);

    if (deleteFriendRequestsError) {
      return jsonResponse(
        {
          error: "Could not delete friend requests",
          details: deleteFriendRequestsError.message,
        },
        500,
      );
    }

    const { error: deleteProfileError } = await adminClient
      .from("profiles")
      .delete()
      .eq("user_id", user.id);

    if (deleteProfileError) {
      return jsonResponse(
        {
          error: "Could not delete profile",
          details: deleteProfileError.message,
        },
        500,
      );
    }

    const { error: deleteUserError } = await adminClient.auth.admin.deleteUser(user.id, false);

    if (deleteUserError) {
      return jsonResponse(
        {
          error: "Could not delete Supabase user",
          details: deleteUserError.message,
        },
        500,
      );
    }

    return jsonResponse({ ok: true, deleted_user_id: user.id });
  } catch (error) {
    return jsonResponse(
      {
        error: "Unexpected error",
        details: error instanceof Error ? error.message : String(error),
      },
      500,
    );
  }
});
