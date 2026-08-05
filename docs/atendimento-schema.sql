-- =====================================================================
-- Atendimento (WhatsApp/Instagram/Messenger) — schema + RLS
-- Rode este arquivo inteiro no SQL Editor do Supabase (projeto JJ Solene).
-- Não precisa rodar em partes — é seguro rodar tudo de uma vez.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Tabela: conversations
-- Uma linha por conversa (WhatsApp = telefone; Instagram/Messenger = PSID/IGSID)
-- ---------------------------------------------------------------------
create table if not exists conversations (
  id uuid primary key default gen_random_uuid(),
  channel text not null check (channel in ('whatsapp','instagram','messenger')),
  external_thread_id text not null, -- WhatsApp: telefone em E.164 (ex: 5511987654321); Instagram/Messenger: PSID/IGSID do Meta
  customer_id uuid references customers(id),
  customer_name text,
  customer_phone text,
  status text not null default 'unclaimed' check (status in ('unclaimed','claimed','closed')),
  assigned_to uuid references profiles(id),
  claimed_at timestamptz,
  last_message_at timestamptz not null default now(),
  last_message_preview text,
  unread_count int not null default 0,
  created_at timestamptz not null default now(),
  unique (channel, external_thread_id)
);

-- ---------------------------------------------------------------------
-- Tabela: messages
-- Uma linha por mensagem (recebida ou enviada) dentro de uma conversa
-- ---------------------------------------------------------------------
create table if not exists messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references conversations(id) on delete cascade,
  direction text not null check (direction in ('inbound','outbound')),
  sender_type text not null check (sender_type in ('customer','attendant','auto')),
  sender_profile_id uuid references profiles(id), -- preenchido quando sender_type='attendant'
  body text not null,
  meta_message_id text, -- id da mensagem dado pela Meta (dedupe de webhook + status de entrega)
  template_key text,    -- preenchido quando enviada via message_templates (ex: 'order_confirmed')
  status text not null default 'sent' check (status in ('queued','sent','delivered','read','failed')),
  error_detail text,
  created_at timestamptz not null default now()
);

create unique index if not exists messages_meta_message_id_uq
  on messages(meta_message_id) where meta_message_id is not null;
create index if not exists messages_conversation_id_idx
  on messages(conversation_id, created_at);

-- ---------------------------------------------------------------------
-- Tabela: message_templates
-- Textos de resposta automática, editáveis pelo admin (Configurações)
-- ---------------------------------------------------------------------
create table if not exists message_templates (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,           -- 'first_contact' | 'order_confirmed' | futuras chaves
  label text not null,                -- mostrado no admin, ex: "Primeira mensagem automática"
  body text not null,                 -- texto editável; aceita {{customer_name}}, {{total}}, {{order_id}}
  meta_template_name text,            -- obrigatório só para mensagens iniciadas pela empresa fora da janela de 24h (ex: order_confirmed)
  active boolean not null default true,
  updated_at timestamptz not null default now()
);

insert into message_templates (key, label, body, meta_template_name)
values
  ('first_contact', 'Primeira mensagem automática',
   'Oi! Recebemos sua mensagem e já já uma de nós te responde. 💛', null),
  ('order_confirmed', 'Pedido confirmado',
   'Oi {{customer_name}}! Seu pedido foi confirmado e já está sendo preparado. Total: {{total}}. Obrigada pela confiança! 💛',
   'pedido_confirmado_v1')
on conflict (key) do nothing;

-- ---------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------
alter table conversations enable row level security;
alter table messages enable row level security;
alter table message_templates enable row level security;

-- conversations: não-atribuída é visível pra qualquer autenticado; atribuída só pra
-- quem assumiu + admin (via is_admin(), já existente no projeto)
create policy conversations_select on conversations for select to authenticated
  using (status = 'unclaimed' or assigned_to = auth.uid() or is_admin());

-- "assumir" é um UPDATE condicional (feito pelo app: .eq('status','unclaimed') na mesma
-- chamada) — a policy só garante que ninguém edita conversa de outra pessoa por fora
create policy conversations_update on conversations for update to authenticated
  using (status = 'unclaimed' or assigned_to = auth.uid() or is_admin())
  with check (assigned_to = auth.uid() or is_admin());

-- inserts de conversations só acontecem pelo Edge Function (service role, bypassa RLS)
-- não é necessário criar policy de insert pra usuários autenticados

-- messages: visível se a conversa-pai for visível
create policy messages_select on messages for select to authenticated
  using (exists (
    select 1 from conversations c where c.id = conversation_id
      and (c.status = 'unclaimed' or c.assigned_to = auth.uid() or is_admin())
  ));

-- respostas manuais são inseridas direto pelo app como o atendente autenticado
create policy messages_insert on messages for insert to authenticated
  with check (
    direction = 'outbound' and sender_profile_id = auth.uid()
    and exists (
      select 1 from conversations c where c.id = conversation_id
        and (c.status = 'unclaimed' or c.assigned_to = auth.uid() or is_admin())
    )
  );

-- message_templates: só admin edita (mensagens automáticas são configuração da loja)
create policy message_templates_select on message_templates for select to authenticated
  using (is_admin());
create policy message_templates_update on message_templates for update to authenticated
  using (is_admin()) with check (is_admin());

-- =====================================================================
-- IMPORTANTE antes de rodar: este script pressupõe que a função is_admin()
-- já existe no projeto (ela está listada no CLAUDE.md como RPC já em uso).
-- Se o CREATE POLICY der erro "function is_admin() does not exist", rode:
--   select pg_get_functiondef('is_admin'::regproc);
-- e me mande o resultado antes de tentar de novo.
-- =====================================================================
