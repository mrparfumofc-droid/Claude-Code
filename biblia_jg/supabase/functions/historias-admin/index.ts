// Edge Function "historias-admin": manutenção das mídias do app Bíblia JG (histórias, narrações, leitura gravada).
// Com a chave de envio guardada no PC do dono (aqui fica apenas o SHA-256 dela):
//  - POST ?path=img/x.jpg  (corpo binário)  -> grava no bucket público "historias"
//  - POST JSON {tts:{text,voice,model}}      -> devolve a narração (PCM/WAV) gerada pelo Gemini TTS
//  - POST JSON {fila:true}                   -> capítulos que o leitor pediu para ouvir e ainda não têm gravação
//  - POST JSON {feito:[[versao,livro,cap]]}  -> tira da fila o que já foi gravado
//  - POST JSON {narr_fila:true}              -> textos do Panorama que o app narrou sem gravação
//  - POST JSON {narr_feito:[chave]}          -> tira da fila os textos já gravados
// Com a chave do app (x-app-key):
//  - POST JSON {quero:{v,b,c}}               -> põe na fila um capítulo de uma versão livre (domínio público)
//  - POST JSON {narrar:"texto"}              -> põe na fila um texto de apresentação para gravar com a voz Algieba
//  - POST JSON {voz:"Algieba"}               -> (versões antigas do app) guarda a voz escolhida
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.49.4";

const ADMIN_SHA256 = "23db2471ad04bcbcf726f2bafede9605ee093c33fbce50f5728cd750f2a4cb6e";
const VOZES = ["Charon", "Orus", "Algenib", "Algieba", "Alnilam", "Sadaltager"];
// Só versões de domínio público ou licença livre podem ser gravadas.
const VERSOES_LIVRES = ["blivre", "alm1911", "tb", "kjv"];
const FILA_MAX = 300;
const NARR_MAX = 3000;

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-app-key",
};
const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...cors, "Content-Type": "application/json" } });

async function sha256(text: string) {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

/** Mesma chave do app (NarrationCloud.keyFor) e do narr.py: dois FNV-1a de 32 bits do UTF-8 normalizado. */
function narrKey(text: string) {
  const b = new TextEncoder().encode(text.trim().split(/\s+/).join(" "));
  const fnv = (bytes: Iterable<number>) => {
    let h = 0x811c9dc5;
    for (const x of bytes) h = Math.imul(h ^ x, 0x01000193) >>> 0;
    return h.toString(16).padStart(8, "0");
  };
  return fnv(b) + fnv([...b].reverse());
}

const TIPOS: Record<string, string> = { jpg: "image/jpeg", mp3: "audio/mpeg", ogg: "audio/ogg", json: "application/json" };

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "método" }, 405);
  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const key = req.headers.get("x-admin-key") ?? "";
  const isAdmin = key !== "" && (await sha256(key)) === ADMIN_SHA256;

  if (!isAdmin) {
    const appKey = req.headers.get("x-app-key") ?? "";
    const { data: config } = await admin.from("ai_config").select("app_key_sha256").eq("id", 1).single();
    if (!config || !appKey || (await sha256(appKey)) !== config.app_key_sha256) return json({ error: "não autorizado" }, 401);
    const body = await req.json().catch(() => ({}));

    // O leitor quis ouvir um capítulo que ainda não tem gravação: entra na fila.
    if (body.quero && typeof body.quero === "object") {
      const v = String(body.quero.v ?? ""), b = Number(body.quero.b), c = Number(body.quero.c);
      if (!VERSOES_LIVRES.includes(v) || !Number.isInteger(b) || !Number.isInteger(c) || b < 1 || b > 66 || c < 1 || c > 150) {
        return json({ error: "pedido inválido" }, 400);
      }
      const { count } = await admin.from("leitura_fila").select("*", { count: "exact", head: true });
      if ((count ?? 0) >= FILA_MAX) return json({ ok: false, cheia: true });
      const ins = await admin.from("leitura_fila").upsert({ versao: v, livro: b, cap: c }, { onConflict: "versao,livro,cap", ignoreDuplicates: true });
      if (ins.error) return json({ error: "fila", detail: ins.error.message }, 500);
      return json({ ok: true });
    }

    // Uma apresentação foi narrada com a voz do aparelho: o texto entra na fila de gravação.
    if (typeof body.narrar === "string") {
      const texto = body.narrar.trim().split(/\s+/).join(" ");
      if (texto.length < 20 || texto.length > 2500) return json({ error: "texto inválido" }, 400);
      const { count } = await admin.from("narr_fila").select("*", { count: "exact", head: true });
      if ((count ?? 0) >= NARR_MAX) return json({ ok: false, cheia: true });
      const ins = await admin.from("narr_fila").upsert({ chave: narrKey(texto), texto }, { onConflict: "chave", ignoreDuplicates: true });
      if (ins.error) return json({ error: "fila", detail: ins.error.message }, 500);
      return json({ ok: true });
    }

    if (typeof body.voz !== "string" || !VOZES.includes(body.voz)) return json({ error: "pedido inválido" }, 400);
    const raw = new TextEncoder().encode(JSON.stringify({ voz: body.voz, quando: new Date().toISOString() }));
    const up = await admin.storage.from("historias").upload("config/voz.json", raw, {
      contentType: "application/json",
      upsert: true,
      cacheControl: "60",
    });
    if (up.error) return json({ error: "upload", detail: up.error.message }, 500);
    return json({ ok: true, voz: body.voz });
  }

  const url = new URL(req.url);
  const path = url.searchParams.get("path");
  if (path) {
    const m = /^[a-z0-9_\-\/]+\.(jpg|mp3|ogg|json)$/.exec(path);
    if (!m || path.includes("..")) return json({ error: "caminho inválido" }, 400);
    const bytes = new Uint8Array(await req.arrayBuffer());
    if (bytes.length === 0 || bytes.length > 8_000_000) return json({ error: "tamanho inválido" }, 400);
    const up = await admin.storage.from("historias").upload(path, bytes, {
      contentType: TIPOS[m[1]],
      upsert: true,
      cacheControl: path.endsWith(".json") ? "60" : "31536000",
    });
    if (up.error) return json({ error: "upload", detail: up.error.message }, 500);
    return json({ ok: true, path, bytes: bytes.length });
  }

  const body = await req.json().catch(() => ({}));

  if (body.fila === true) {
    const { data, error } = await admin.from("leitura_fila").select("versao,livro,cap,pedido_em").order("pedido_em").limit(FILA_MAX);
    if (error) return json({ error: "fila", detail: error.message }, 500);
    return json({ ok: true, fila: data ?? [] });
  }
  if (Array.isArray(body.feito)) {
    let n = 0;
    for (const it of body.feito.slice(0, 500)) {
      if (!Array.isArray(it) || it.length !== 3) continue;
      const del = await admin.from("leitura_fila").delete().eq("versao", String(it[0])).eq("livro", Number(it[1])).eq("cap", Number(it[2]));
      if (!del.error) n++;
    }
    return json({ ok: true, tirados: n });
  }
  if (body.narr_fila === true) {
    const { data, error } = await admin.from("narr_fila").select("chave,texto,pedido_em").order("pedido_em").limit(500);
    if (error) return json({ error: "fila", detail: error.message }, 500);
    return json({ ok: true, fila: data ?? [] });
  }
  if (Array.isArray(body.narr_feito)) {
    const chaves = body.narr_feito.filter((k: unknown) => typeof k === "string").slice(0, 1000);
    const del = await admin.from("narr_fila").delete().in("chave", chaves);
    return json({ ok: !del.error, tirados: chaves.length });
  }

  const tts = body.tts as { text?: string; voice?: string; model?: string } | undefined;
  if (!tts?.text || !tts.model) return json({ error: "faltou tts.text/model" }, 400);
  const r = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${tts.model}:generateContent`, {
    method: "POST",
    headers: { "x-goog-api-key": Deno.env.get("GEMINI_API_KEY")!, "Content-Type": "application/json" },
    body: JSON.stringify({
      contents: [{ role: "user", parts: [{ text: tts.text }] }],
      generationConfig: {
        responseModalities: ["AUDIO"],
        speechConfig: { voiceConfig: { prebuiltVoiceConfig: { voiceName: tts.voice ?? "Algieba" } } },
      },
    }),
  });
  const j = await r.json().catch(() => ({}));
  if (!r.ok) return json({ error: "gemini", status: r.status, detail: JSON.stringify(j).slice(0, 900) }, r.status === 429 ? 429 : 502);
  const parts = j.candidates?.[0]?.content?.parts ?? [];
  const au = parts.find((p: { inlineData?: { data: string } }) => p.inlineData?.data);
  if (!au) return json({ error: "sem áudio", detail: JSON.stringify(j).slice(0, 700) }, 502);
  const bytes = Uint8Array.from(atob(au.inlineData.data), (c) => c.charCodeAt(0));
  return new Response(bytes, {
    headers: { "Content-Type": "application/octet-stream", "x-audio-mime": au.inlineData.mimeType ?? "audio/L16;rate=24000" },
  });
});
