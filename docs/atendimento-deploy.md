# Atendimento — publicando os Edge Functions

Depois de rodar o SQL (`docs/atendimento-schema.sql`) e ter em mãos os dados da Fase 0
(`docs/atendimento-setup-meta.md`, item 10), publique os dois Edge Functions com o Supabase
CLI (se não tiver instalado: `npm install -g supabase`).

```bash
supabase login
supabase link --project-ref pcvcpylcpuvprpkydbxf

supabase secrets set \
  META_APP_SECRET=coloque_aqui \
  META_VERIFY_TOKEN=coloque_aqui \
  WHATSAPP_TOKEN=coloque_aqui \
  WHATSAPP_PHONE_NUMBER_ID=coloque_aqui \
  PAGE_TOKEN=coloque_aqui \
  FACEBOOK_PAGE_ID=coloque_aqui

supabase functions deploy meta-webhook
supabase functions deploy meta-send
```

`SUPABASE_URL` e `SUPABASE_SERVICE_ROLE_KEY` **não** precisam ser configurados manualmente —
o Supabase já injeta essas duas automaticamente em toda function.

Depois do deploy, a URL do webhook pra colar no painel da Meta (item 7 do checklist) é:

```
https://pcvcpylcpuvprpkydbxf.supabase.co/functions/v1/meta-webhook
```

Pra testar o handshake de verificação manualmente antes de registrar na Meta:

```bash
curl "https://pcvcpylcpuvprpkydbxf.supabase.co/functions/v1/meta-webhook?hub.mode=subscribe&hub.verify_token=SEU_TOKEN&hub.challenge=12345"
```

Deve responder `12345`. Se responder "Forbidden", o `META_VERIFY_TOKEN` configurado no
secret não bate com o que foi passado na URL.
