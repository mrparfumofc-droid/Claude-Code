// Edge Function "music": lista as músicas de fundo do app Bíblia JG.
// As músicas ficam no bucket privado "musicas" (Supabase Storage), com a lista em
// "musicas.json". Só o app (cabeçalho x-app-key, conferido pelo hash em ai_config)
// recebe os links, que são assinados e valem por 12 horas.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.49.4";

const BUCKET = "musicas";
const LINK_SECONDS = 12 * 60 * 60;

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-app-key, x-device-id",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

async function sha256(text: string) {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

type Track = { file: string; title: string; seconds: number; bytes: number };

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  const { data: config } = await admin.from("ai_config").select("app_key_sha256").eq("id", 1)
    .single();
  const appKey = req.headers.get("x-app-key") ?? "";
  if (!config || !appKey || (await sha256(appKey)) !== config.app_key_sha256) {
    return json({ error: "Acesso não autorizado." }, 401);
  }

  const { data: manifest, error } = await admin.storage.from(BUCKET).download("musicas.json");
  if (error || !manifest) return json({ error: "Lista de músicas indisponível." }, 500);
  let tracks: Track[];
  try {
    const parsed = JSON.parse((await manifest.text()).replace(/^﻿/, ""));
    tracks = Array.isArray(parsed) ? parsed : [parsed];
  } catch {
    return json({ error: "Lista de músicas inválida." }, 500);
  }

  const { data: signed, error: signError } = await admin.storage.from(BUCKET)
    .createSignedUrls(tracks.map((t) => t.file), LINK_SECONDS);
  if (signError || !signed) return json({ error: "Não consegui gerar os links." }, 500);
  const urls = new Map(signed.map((s) => [s.path, s.signedUrl]));

  return json({
    expiresIn: LINK_SECONDS,
    tracks: tracks
      .filter((t) => urls.get(t.file))
      .map((t) => ({ ...t, url: urls.get(t.file) })),
  });
});
