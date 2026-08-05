// Envia mensagens (resposta manual do atendente OU automação por template, ex: pedido
// confirmado) via WhatsApp/Instagram/Messenger. Ao contrário do meta-webhook (público),
// esta function EXIGE o JWT da sessão de quem está chamando — só usuários autenticados do
// sistema podem disparar envio, e a visibilidade da conversa é revalidada aqui mesmo (a
// function usa service role e não passa pela RLS automaticamente).
import {
  createAdminClient,
  fillTemplate,
  sendMessengerText,
  sendWhatsAppTemplate,
  sendWhatsAppText,
} from "../_shared/meta.ts";

const WHATSAPP_TOKEN = Deno.env.get("WHATSAPP_TOKEN") ?? "";
const WHATSAPP_PHONE_NUMBER_ID = Deno.env.get("WHATSAPP_PHONE_NUMBER_ID") ?? "";
const PAGE_TOKEN = Deno.env.get("PAGE_TOKEN") ?? "";
const FACEBOOK_PAGE_ID = Deno.env.get("FACEBOOK_PAGE_ID") ?? "";

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ ok: false, error: "Method not allowed" }, 405);

  const authHeader = req.headers.get("authorization") || "";
  const jwt = authHeader.replace(/^Bearer\s+/i, "");
  if (!jwt) return json({ ok: false, error: "Não autenticado" }, 401);

  const supabase = createAdminClient();
  const { data: userData, error: userErr } = await supabase.auth.getUser(jwt);
  if (userErr || !userData?.user) return json({ ok: false, error: "Sessão inválida" }, 401);
  const callerId = userData.user.id;

  const { data: profile } = await supabase.from("profiles").select("role").eq("id", callerId).maybeSingle();
  const isAdmin = profile?.role === "admin";

  let payload: any;
  try {
    payload = await req.json();
  } catch {
    return json({ ok: false, error: "JSON inválido" }, 400);
  }

  try {
    if (payload.template_key) {
      const messageId = await sendViaTemplate(supabase, payload);
      return json({ ok: true, message_id: messageId });
    }
    if (payload.conversation_id && typeof payload.body === "string") {
      const messageId = await sendManualReply(supabase, payload, callerId, isAdmin);
      return json({ ok: true, message_id: messageId });
    }
    return json({ ok: false, error: "Requisição inválida — informe conversation_id+body ou template_key" }, 400);
  } catch (e) {
    console.error("meta-send erro:", e);
    return json({ ok: false, error: String((e as Error)?.message || e) }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

async function sendManualReply(
  supabase: any,
  payload: any,
  callerId: string,
  isAdmin: boolean,
): Promise<string | null> {
  const { data: conv, error } = await supabase.from("conversations").select("*").eq(
    "id",
    payload.conversation_id,
  ).maybeSingle();
  if (error || !conv) throw new Error("Conversa não encontrada");

  const allowed = conv.status === "unclaimed" || conv.assigned_to === callerId || isAdmin;
  if (!allowed) throw new Error("Você não tem acesso a esta conversa");

  let messageId: string | null = null;
  if (conv.channel === "whatsapp") {
    messageId = await sendWhatsAppText(WHATSAPP_PHONE_NUMBER_ID, WHATSAPP_TOKEN, conv.external_thread_id, payload.body);
  } else {
    messageId = await sendMessengerText(FACEBOOK_PAGE_ID, PAGE_TOKEN, conv.external_thread_id, payload.body);
  }

  await supabase.from("messages").insert({
    conversation_id: conv.id,
    direction: "outbound",
    sender_type: "attendant",
    sender_profile_id: callerId,
    body: payload.body,
    meta_message_id: messageId,
  });
  await supabase.from("conversations").update({
    last_message_at: new Date().toISOString(),
    last_message_preview: payload.body,
    unread_count: 0,
  }).eq("id", conv.id);

  return messageId;
}

async function sendViaTemplate(supabase: any, payload: any): Promise<string | null> {
  const phone = String(payload.phone || "").replace(/\D/g, "");
  if (!phone) throw new Error("Telefone inválido");

  const { data: tpl } = await supabase.from("message_templates").select("*").eq("key", payload.template_key)
    .maybeSingle();
  if (!tpl || !tpl.active) throw new Error("Template não encontrado ou inativo: " + payload.template_key);
  if (!tpl.meta_template_name) throw new Error("Template sem nome aprovado na Meta — configure meta_template_name");

  const conv = await findOrCreateWhatsAppConversation(supabase, phone, payload.params?.customer_name);

  const filledBody = fillTemplate(tpl.body, payload.params || {});
  // A ordem dos parâmetros abaixo precisa bater com a ordem das variáveis {{1}}, {{2}}...
  // no template aprovado na Meta — hoje fixo em [customer_name, total] pro template
  // "pedido_confirmado_v1"; ajustar aqui se o template for alterado.
  const orderedParams = [payload.params?.customer_name || "", payload.params?.total || ""];
  const messageId = await sendWhatsAppTemplate(
    WHATSAPP_PHONE_NUMBER_ID,
    WHATSAPP_TOKEN,
    phone,
    tpl.meta_template_name,
    orderedParams,
  );

  await supabase.from("messages").insert({
    conversation_id: conv.id,
    direction: "outbound",
    sender_type: "auto",
    body: filledBody,
    meta_message_id: messageId,
    template_key: tpl.key,
  });
  await supabase.from("conversations").update({
    last_message_at: new Date().toISOString(),
    last_message_preview: filledBody,
  }).eq("id", conv.id);

  return messageId;
}

async function findOrCreateWhatsAppConversation(supabase: any, phone: string, customerName?: string) {
  const { data: existing } = await supabase.from("conversations")
    .select("id").eq("channel", "whatsapp").eq("external_thread_id", phone).maybeSingle();
  if (existing) return existing;

  const { data: created, error } = await supabase.from("conversations").insert({
    channel: "whatsapp",
    external_thread_id: phone,
    customer_name: customerName || null,
    customer_phone: phone,
    status: "unclaimed",
  }).select("id").single();
  if (error) throw error;
  return created;
}
