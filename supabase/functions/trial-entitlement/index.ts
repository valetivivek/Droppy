import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.21.0";

const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-trial-key",
};

serve(async (req) => {
    // Handle CORS preflight requests
    if (req.method === "OPTIONS") {
        return new Response("ok", { headers: corsHeaders });
    }

    try {
        // 1. Validate Secret / API Key
        // The client sends the public key as a Bearer token or x-trial-key.
        // In a real production environment, you might want to validate this against a secret
        // or ensure the request signature is valid.
        // For now, we mirror the client's expectation that it sends a key.
        const authHeader = req.headers.get("Authorization");
        const trialKeyHeader = req.headers.get("x-trial-key");

        if (!authHeader && !trialKeyHeader) {
            return new Response(JSON.stringify({ error: "Missing authorization" }), {
                status: 401,
                headers: { ...corsHeaders, "Content-Type": "application/json" },
            });
        }

        // 2. Parse Request Body
        const { device_id, account_hash, app_bundle_id, app_version } = await req.json();
        if (!device_id) {
            return new Response(JSON.stringify({ error: "Missing device_id" }), {
                status: 400,
                headers: { ...corsHeaders, "Content-Type": "application/json" },
            });
        }
        const normalizedAccountHash = normalizeAccountHash(account_hash);

        // 3. Initialize Supabase Admin Client (Service Role)
        // We need service role to read/write to the trial_entitlements table which has RLS enabled
        const supabaseAdmin = createClient(
            Deno.env.get("SUPABASE_URL") ?? "",
            Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
        );

        // 4. Determine Action based on URL path
        const url = new URL(req.url);
        const action = url.pathname.split("/").pop(); // "status" or "start"

        if (action === "start") {
            return await handleStartTrial(supabaseAdmin, device_id, normalizedAccountHash);
        } else if (action === "status") {
            return await handleStatusCheck(supabaseAdmin, device_id, normalizedAccountHash);
        } else {
            return new Response(JSON.stringify({ error: "Invalid endpoint" }), {
                status: 404,
                headers: { ...corsHeaders, "Content-Type": "application/json" },
            });
        }

    } catch (error) {
        return new Response(JSON.stringify({ error: error.message }), {
            status: 500,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
    }
});

async function handleStatusCheck(supabase: any, device_id: string, account_hash: string | null) {
    const now = new Date();
    const serverNow = Math.floor(now.getTime() / 1000);

    const data = await findEntitlement(supabase, device_id, account_hash);

    if (!data) {
        // No trial record found -> Eligible
        return new Response(
            JSON.stringify({
                active: false,
                consumed: false,
                eligible: true,
                server_now: serverNow,
                message: "Start your 3-day trial.",
            }),
            { headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
    }

    await backfillAccountHashIfMissing(supabase, data, account_hash);

    // Trial record exists
    const expiresAt = new Date(data.expires_at).getTime() / 1000;
    const startedAt = new Date(data.started_at).getTime() / 1000;
    const active = data.consumed && serverNow < expiresAt;

    return new Response(
        JSON.stringify({
            active: active,
            consumed: data.consumed,
            eligible: false,
            started_at: startedAt,
            expires_at: expiresAt,
            server_now: serverNow,
            message: active
                ? `Trial active. Ends in ${Math.ceil((expiresAt - serverNow) / 86400)} days.`
                : "Trial expired.",
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
}

async function handleStartTrial(supabase: any, device_id: string, account_hash: string | null) {
    const now = new Date();
    const serverNow = Math.floor(now.getTime() / 1000);
    const trialDurationSeconds = 3 * 24 * 60 * 60; // 3 days

    // 1. Check if exists first by device or account
    const existing = await findEntitlement(supabase, device_id, account_hash);

    if (existing) {
        await backfillAccountHashIfMissing(supabase, existing, account_hash);

        // Already exists, return current status
        const expiresAt = new Date(existing.expires_at).getTime() / 1000;
        const startedAt = new Date(existing.started_at).getTime() / 1000;
        const active = existing.consumed && serverNow < expiresAt;

        return new Response(
            JSON.stringify({
                active: active,
                consumed: existing.consumed,
                eligible: false,
                started_at: startedAt,
                expires_at: expiresAt,
                server_now: serverNow,
                message: active ? "Trial is already active." : "Trial has already been used.",
            }),
            { headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
    }

    // 2. Start new trial
    const expiresAtDate = new Date(now.getTime() + trialDurationSeconds * 1000);
    const expiresAt = Math.floor(expiresAtDate.getTime() / 1000);

    const { error: insertError } = await supabase
        .from("trial_entitlements")
        .insert([
            {
                device_id: device_id,
                account_hash: account_hash,
                started_at: now.toISOString(),
                expires_at: expiresAtDate.toISOString(),
                consumed: true,
            },
        ]);

    if (insertError) {
        if (insertError.code === "23505") { // Unique violation race condition
            return handleStartTrial(supabase, device_id, account_hash); // Retry/Return existing
        }
        throw insertError;
    }

    return new Response(
        JSON.stringify({
            active: true,
            consumed: true,
            eligible: false,
            started_at: serverNow,
            expires_at: expiresAt,
            server_now: serverNow,
            message: "Trial started successfully.",
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
}

function normalizeAccountHash(value: unknown): string | null {
    if (typeof value !== "string") {
        return null;
    }
    const normalized = value.trim().toLowerCase();
    if (!/^[a-f0-9]{64}$/.test(normalized)) {
        return null;
    }
    return normalized;
}

async function findEntitlement(supabase: any, device_id: string, account_hash: string | null) {
    const { data: byDevice, error: deviceError } = await supabase
        .from("trial_entitlements")
        .select("*")
        .eq("device_id", device_id)
        .maybeSingle();

    if (deviceError) {
        throw deviceError;
    }

    if (byDevice) {
        return byDevice;
    }

    if (!account_hash) {
        return null;
    }

    const { data: byAccount, error: accountError } = await supabase
        .from("trial_entitlements")
        .select("*")
        .eq("account_hash", account_hash)
        .maybeSingle();

    if (accountError) {
        throw accountError;
    }

    return byAccount ?? null;
}

async function backfillAccountHashIfMissing(supabase: any, entitlement: any, account_hash: string | null) {
    if (!account_hash) {
        return;
    }
    if (!entitlement?.id || entitlement.account_hash) {
        return;
    }

    const { error } = await supabase
        .from("trial_entitlements")
        .update({ account_hash })
        .eq("id", entitlement.id)
        .is("account_hash", null);

    if (error && error.code !== "23505") {
        throw error;
    }
}
