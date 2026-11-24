// Edge Function "ai-verse": IA do app Bíblia JG (Gemini).
// A chave do Gemini fica só no servidor (secret GEMINI_API_KEY).
// Acesso: usuário logado OU o app (cabeçalho x-app-key + x-device-id), com limite diário
// por aparelho/usuário e um limite global (tabela ai_config).
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.49.4";

const MODEL = Deno.env.get("GEMINI_MODEL") ?? "gemini-flash-latest";
// Reservas usadas quando o principal esgota a cota (429) ou está sobrecarregado (503).
const FALLBACK_MODELS = (Deno.env.get("GEMINI_FALLBACK_MODELS") ?? "gemini-flash-lite-latest")
  .split(",").map((m) => m.trim()).filter(Boolean);
const MAX_ATTEMPTS = 7;

// Modelos disponíveis na chave (consultado uma vez por instância): versões
// flash-lite/flash mais novas e a família Gemma, que tem cota grátis própria e maior.
let discovered: string[] | null = null;
async function discoverModels(apiKey: string): Promise<string[]> {
  if (discovered) return discovered;
  try {
    const r = await fetch("https://generativelanguage.googleapis.com/v1beta/models?pageSize=300", {
      headers: { "x-goog-api-key": apiKey },
    });
    const j = await r.json();
    const names: string[] = (j.models ?? [])
      .filter((m: { supportedGenerationMethods?: string[] }) =>
        m.supportedGenerationMethods?.includes("generateContent")
      )
      .map((m: { name: string }) => m.name.replace(/^models\//, ""))
      .filter((n: string) => !/(preview|exp|tts|image|live|audio|embedding|thinking|robotics|computer)/.test(n));
    const ver = (n: string) => parseFloat(n.match(/(\d+(\.\d+)?)/)?.[1] ?? "0");
    const size = (n: string) => parseFloat(n.match(/-(\d+)b-/)?.[1] ?? "0");
    const lite = names.filter((n) => /^gemini-[\d.]+-flash-lite$/.test(n)).sort((a, b) => ver(b) - ver(a));
    const flash = names.filter((n) => /^gemini-[\d.]+-flash$/.test(n)).sort((a, b) => ver(b) - ver(a));
    const gemma = names.filter((n) => /^gemma-.*-it$/.test(n))
      .sort((a, b) => ver(b) - ver(a) || size(b) - size(a));
    discovered = [...lite.slice(0, 1), ...flash.slice(0, 1), ...gemma.slice(0, 2)];
  } catch {
    discovered = [];
  }
  return discovered;
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));
// Modelo que esgotou a cota fica de fora por 1 hora (evita perder tempo a cada pedido).
const exhausted = new Map<string, number>();
const ATTEMPT_TIMEOUT_MS = 40_000;
const MAX_TURNS = 30;
const MAX_CHARS = 6000;

const BASE = `Você é o assistente de estudo bíblico do app "Bíblia JG". Responda sempre em português do Brasil, com Markdown (títulos curtos, listas, negrito). Seja fiel ao texto bíblico, pastoral e ao mesmo tempo profundo. Cite referências bíblicas no formato "Livro capítulo:versículo" (ex.: João 3:16) para que o app as transforme em links.`;

// Perfis teológicos (texto próprio do app).
const PROFILES: Record<string, string> = {
  assembleiano:
    "Perspectiva pentecostal clássica das Assembleias de Deus no Brasil (Declaração de Fé da CGADB): autoridade e inerrância das Escrituras, salvação pela graça mediante a fé, batismo no Espírito Santo com evidência inicial de falar em línguas, atualidade dos dons espirituais, santificação, cura divina e escatologia pré-milenista e pré-tribulacionista. Tom pastoral, com aplicação prática para a igreja local.",
  geral:
    "Perspectiva cristã geral e equilibrada. Quando houver diferenças entre tradições (reformada, pentecostal, batista, metodista, católica), apresente as principais leituras com respeito, sem tomar partido nem usar tom sectário.",
  academico:
    "Perspectiva acadêmica: exegese histórico-gramatical, línguas originais (hebraico, aramaico e grego com transliteração), crítica textual, arqueologia e fontes extrabíblicas. Separe o consenso dos estudiosos das hipóteses.",
  reformado:
    "Perspectiva reformada: as cinco solas, soberania de Deus, teologia do pacto e leitura cristocêntrica das Escrituras, em diálogo com a tradição dos reformadores e puritanos.",
  batista:
    "Perspectiva batista: autoridade suprema das Escrituras, salvação pela graça mediante a fé, batismo de crentes por imersão, sacerdócio de todos os crentes e autonomia da igreja local.",
  catolico:
    "Perspectiva católica romana: Escritura lida na Tradição e no Magistério da Igreja, Catecismo, sacramentos e os Padres da Igreja.",
};

// Tarefas (o que o app pede).
const TASKS: Record<string, string> = {
  explain: `Explique o versículo ou trecho em detalhes, com estas seções:
1. **O que o texto diz**, em palavras simples.
2. **Contexto**: livro, autor, destinatários, momento histórico e o que vem antes e depois.
3. **Palavras-chave**: termos importantes com o original (hebraico/grego) e transliteração quando ajudar.
4. **Significado e ensino** principal.
5. **Referências cruzadas** com outros versículos.
6. **Aplicação prática** para a vida hoje.
Nas perguntas seguintes, responda de forma direta mantendo o contexto do trecho.`,
  commentary:
    "Escreva um comentário bíblico versículo a versículo do trecho, com contexto histórico, observações exegéticas e aplicação.",
  term:
    "Explique o termo bíblico pedido como um verbete de dicionário bíblico: definição, origem e significado no original, usos na Bíblia (com referências), sentido teológico e aplicação.",
  devotional:
    "Escreva um devocional original para o dia, de 300 a 450 palavras, com: título, versículo-base (citado com referência), reflexão, aplicação prática e uma oração curta no final.",
  story:
    "Conte a história bíblica pedida de forma envolvente e fiel ao texto, em linguagem acessível (também para jovens), com as referências bíblicas onde ela está, e termine com 'Lições da história' em tópicos.",
  quiz:
    'Crie perguntas bíblicas de múltipla escolha sobre o tema pedido. Responda SOMENTE com JSON válido no formato {"perguntas":[{"pergunta":"...","opcoes":["a","b","c","d"],"correta":0,"referencia":"Livro cap:vers","explicacao":"..."}]}, sem texto fora do JSON.',
  sermon:
    "Prepare um esboço de pregação expositiva sobre o trecho: título, texto-base, introdução, tema central, 3 pontos principais com explicação, ilustração e aplicação, conclusão e apelo.",
  chat: "Converse sobre a Bíblia e a fé cristã respondendo às perguntas do usuário.",
};

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

type Turn = { role: "user" | "model"; text: string };

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method === "GET") {
    const key = Deno.env.get("GEMINI_API_KEY");
    if (!key) return json({ configured: false });
    const r = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${MODEL}`, {
      headers: { "x-goog-api-key": key },
    });
    return json({ configured: true, geminiOk: r.ok, model: MODEL });
  }
  if (req.method !== "POST") return json({ error: "Método não permitido" }, 405);

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  const { data: config } = await admin.from("ai_config").select("*").eq("id", 1).single();

  // Quem está pedindo: usuário logado ou aparelho com a chave do app.
  let subject: string | null = null;
  const auth = req.headers.get("Authorization") ?? "";
  const userClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: auth } } },
  );
  const { data: { user } } = await userClient.auth.getUser();
  if (user && !user.is_anonymous) subject = `user:${user.id}`;
  if (!subject) {
    const appKey = req.headers.get("x-app-key") ?? "";
    const device = req.headers.get("x-device-id") ?? "";
    if (
      config && appKey && (await sha256(appKey)) === config.app_key_sha256 &&
      /^[A-Za-z0-9-]{16,64}$/.test(device)
    ) {
      subject = `device:${device}`;
    }
  }
  if (!subject) return json({ error: "Acesso não autorizado à IA." }, 401);

  let body: {
    task?: string;
    profile?: string;
    reference?: string;
    version?: string;
    verseText?: string;
    messages?: Turn[];
  };
  try {
    body = await req.json();
  } catch {
    return json({ error: "Pedido inválido" }, 400);
  }
  const task = TASKS[body.task ?? "explain"] ? (body.task ?? "explain") : "explain";
  const profile = PROFILES[body.profile ?? "assembleiano"] ? (body.profile ?? "assembleiano") : "assembleiano";
  const reference = String(body.reference ?? "").slice(0, 300);
  const version = String(body.version ?? "").slice(0, 50);
  const verseText = String(body.verseText ?? "").slice(0, MAX_CHARS);
  const messages = (Array.isArray(body.messages) ? body.messages : [])
    .slice(-MAX_TURNS)
    .map((m) => ({
      role: m?.role === "model" ? "model" : "user",
      text: String(m?.text ?? "").slice(0, MAX_CHARS),
    }))
    .filter((m) => m.text.trim().length > 0);
  if (messages.length === 0 || messages.at(-1)!.role !== "user") {
    return json({ error: "Falta a pergunta." }, 400);
  }

  const { data: usage, error: usageError } = await admin.rpc("ai_usage_hit", { p_subject: subject });
  if (usageError) return json({ error: "Falha ao registrar uso." }, 500);
  const hit = Array.isArray(usage) ? usage[0] : usage;
  if (config && hit?.subject_count > config.subject_daily_limit) {
    return json({ error: `Limite diário de ${config.subject_daily_limit} pedidos à IA atingido. Volte amanhã.` }, 429);
  }
  if (config && hit?.global_count > config.global_daily_limit) {
    return json({ error: "A IA atingiu o limite de uso de hoje. Volte amanhã." }, 429);
  }

  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) return json({ error: "A IA ainda não foi configurada no servidor." }, 503);

  const context = reference
    ? `Texto bíblico: ${reference}${version ? ` (${version})` : ""}\n"${verseText}"\n\n`
    : "";
  const contents = messages.map((m, i) => ({
    role: m.role,
    parts: [{ text: i === 0 ? `${context}${m.text}` : m.text }],
  }));
  const system = `${BASE}\n\nPerfil teológico: ${PROFILES[profile]}\n\nTarefa: ${TASKS[task]}`;

  // Tenta o modelo principal e, se a cota/servidor dele estiver esgotado, os reservas.
  const build = (gemma: boolean) =>
    JSON.stringify(
      gemma
        ? {
          // Gemma não aceita systemInstruction: as instruções vão no início da conversa.
          contents: contents.map((c, i) =>
            i === 0 ? { ...c, parts: [{ text: `${system}\n\n---\n\n${c.parts[0].text}` }] } : c
          ),
          generationConfig: { maxOutputTokens: 8192 },
        }
        : {
          systemInstruction: { parts: [{ text: system }] },
          contents,
          generationConfig: {
            maxOutputTokens: 8192,
            ...(task === "quiz" ? { responseMimeType: "application/json" } : {}),
          },
        },
    );
  const models = [...new Set([MODEL, ...FALLBACK_MODELS, ...(await discoverModels(apiKey))])];
  let res: Response | null = null;
  // deno-lint-ignore no-explicit-any
  let data: any = {};
  let quota = false;
  let busy = false;
  let attempts = 0;
  outer: for (const model of models) {
    if ((exhausted.get(model) ?? 0) > Date.now()) {
      quota = true;
      continue;
    }
    for (let tryNo = 0; tryNo < 2; tryNo++) {
      if (attempts++ >= MAX_ATTEMPTS) break outer;
      try {
        res = await fetch(
          `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
          {
            method: "POST",
            headers: { "Content-Type": "application/json", "x-goog-api-key": apiKey },
            body: build(model.startsWith("gemma")),
            signal: AbortSignal.timeout(ATTEMPT_TIMEOUT_MS),
          },
        );
      } catch {
        console.error("Gemini", model, "timeout");
        res = null;
        busy = true;
        continue outer; // demorou demais: passa para o próximo modelo
      }
      data = await res.json().catch(() => ({}));
      if (res.ok) break outer;
      console.error("Gemini", model, res.status, JSON.stringify(data).slice(0, 300));
      if (res.status === 429 && JSON.stringify(data).includes("quota")) {
        quota = true;
        exhausted.set(model, Date.now() + 60 * 60 * 1000);
      }
      if (res.status === 503) {
        busy = true;
        await sleep(1200); // sobrecarga costuma passar em segundos: tenta de novo uma vez
        continue;
      }
      if (res.status === 429 || res.status === 404 || res.status === 400) continue outer;
      break outer;
    }
  }
  if (!res || !res.ok) {
    return json({
      error: busy
        ? "Os servidores de IA do Google estão sobrecarregados agora. Tente de novo em 1 minuto."
        : quota
        ? "A cota grátis da IA de hoje acabou (limite do Google). Ela volta amanhã."
        : "A IA não respondeu agora. Tente de novo em instantes.",
    }, 502);
  }
  const text = (data?.candidates?.[0]?.content?.parts ?? [])
    .filter((p: { text?: string; thought?: boolean }) => p.text && !p.thought)
    .map((p: { text: string }) => p.text)
    .join("");
  if (!text) return json({ error: "A IA não conseguiu responder a essa pergunta." }, 502);
  return json({ text, model: data?.modelVersion ?? MODEL, usedToday: hit?.subject_count });
});
