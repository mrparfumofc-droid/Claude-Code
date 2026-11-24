// Edge Function "ai-verse": explica versículos e conversa sobre eles usando o Gemini.
// A chave fica só no servidor (secret GEMINI_API_KEY). Exige usuário logado (não anônimo)
// e aplica um limite diário por usuário.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.49.4";

const MODEL = Deno.env.get("GEMINI_MODEL") ?? "gemini-flash-latest";
const DAILY_LIMIT = Number(Deno.env.get("AI_DAILY_LIMIT") ?? "200");
const MAX_TURNS = 30;
const MAX_CHARS = 4000;

const SYSTEM = `Você é um professor de Bíblia dentro do app "Bíblia JG". Responda sempre em português do Brasil.
Quando receber um versículo para explicar, faça uma explicação detalhada e organizada com:
1. O que o versículo diz, em palavras simples.
2. Contexto: livro, autor, destinatários e o que acontece antes e depois.
3. Palavras-chave importantes (com o termo original em hebraico ou grego quando ajudar).
4. O significado e os ensinamentos principais.
5. Referências cruzadas com outros versículos.
6. Aplicação prática para a vida hoje.
Use títulos curtos e listas. Seja fiel ao texto bíblico; quando houver interpretações diferentes entre tradições cristãs, apresente-as com respeito e sem impor uma.
Nas perguntas seguintes, responda de forma direta, mantendo o contexto do versículo.
Se perguntarem algo fora de Bíblia, fé ou estudo bíblico, responda brevemente e convide a voltar ao texto.`;

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

type Turn = { role: "user" | "model"; text: string };

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method === "GET") {
    // Diagnóstico: a IA está configurada? (não expõe a chave)
    const key = Deno.env.get("GEMINI_API_KEY");
    if (!key) return json({ configured: false });
    const r = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}`,
      { headers: { "x-goog-api-key": key } },
    );
    return json({ configured: true, geminiOk: r.ok, model: MODEL });
  }
  if (req.method !== "POST") return json({ error: "Método não permitido" }, 405);

  // Usuário logado (Google). Anônimo não pode usar a IA.
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } },
  );
  const { data: { user } } = await supabase.auth.getUser();
  if (!user || user.is_anonymous) {
    return json({ error: "Entre com sua conta Google para usar a IA." }, 401);
  }

  let body: { reference?: string; version?: string; verseText?: string; messages?: Turn[] };
  try {
    body = await req.json();
  } catch {
    return json({ error: "Pedido inválido" }, 400);
  }
  const reference = String(body.reference ?? "").slice(0, 200);
  const version = String(body.version ?? "").slice(0, 50);
  const verseText = String(body.verseText ?? "").slice(0, MAX_CHARS);
  const messages = (Array.isArray(body.messages) ? body.messages : [])
    .slice(-MAX_TURNS)
    .map((m) => ({
      role: m?.role === "model" ? "model" : "user",
      text: String(m?.text ?? "").slice(0, MAX_CHARS),
    }))
    .filter((m) => m.text.trim().length > 0);
  if (!reference || !verseText || messages.length === 0 || messages.at(-1)!.role !== "user") {
    return json({ error: "Faltam o versículo ou a pergunta." }, 400);
  }

  // Limite diário por usuário.
  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  const { data: used, error: usageError } = await admin.rpc("ai_usage_increment", { p_user: user.id });
  if (usageError) return json({ error: "Falha ao registrar uso." }, 500);
  if ((used as number) > DAILY_LIMIT) {
    return json({ error: `Limite diário de ${DAILY_LIMIT} perguntas atingido. Volte amanhã.` }, 429);
  }

  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) return json({ error: "A IA ainda não foi configurada no servidor." }, 503);

  const context = `Versículo: ${reference}${version ? ` (${version})` : ""}\n"${verseText}"`;
  const contents = messages.map((m, i) => ({
    role: m.role,
    parts: [{ text: i === 0 ? `${context}\n\n${m.text}` : m.text }],
  }));

  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-goog-api-key": apiKey },
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: SYSTEM }] },
        contents,
        generationConfig: { maxOutputTokens: 8192 },
      }),
    },
  );
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    console.error("Gemini", res.status, JSON.stringify(data).slice(0, 500));
    return json({ error: "A IA não respondeu agora. Tente de novo em instantes." }, 502);
  }
  const text = (data?.candidates?.[0]?.content?.parts ?? [])
    .filter((p: { text?: string; thought?: boolean }) => p.text && !p.thought)
    .map((p: { text: string }) => p.text)
    .join("");
  if (!text) {
    return json({ error: "A IA não conseguiu responder a essa pergunta." }, 502);
  }
  return json({ text, model: data?.modelVersion ?? MODEL, usedToday: used });
});
