# Atendimento (WhatsApp/Instagram/Messenger) — Checklist de configuração na Meta

Este é um roteiro pra você fazer **fora do código**, direto nos painéis da Meta e do
Supabase. Nenhuma dessas etapas eu consigo fazer por você — envolvem conta de negócio,
verificação de identidade e tokens que só o dono da conta pode gerar.

Siga na ordem. Os itens 1-4 e 6-9 podem ser feitos a qualquer momento; o item 5 (migrar o
número real) deve ser o **último**, depois que eu tiver testado tudo com um número de teste.

## 1. Meta Business Manager
Acesse [business.facebook.com](https://business.facebook.com) e confirme (ou crie) uma conta
de negócio vinculada à Página do Facebook da JJ Solene.

## 2. Página do Facebook
Confirme que existe uma Página do Facebook da loja — é obrigatória tanto pra Messenger
quanto pra Instagram (o Instagram "empresta" a infraestrutura de mensagens da Página).

## 3. Conta do Instagram profissional
No app do Instagram: Configurações → Conta → mude para conta **Profissional** (Empresa ou
Criador de conteúdo), se ainda não for, e vincule essa conta à Página do Facebook do item 2
(Configurações → Contas vinculadas).

## 4. Criar o App na Meta
Acesse [developers.facebook.com](https://developers.facebook.com) → Meus Apps → Criar App →
tipo **"Negócios"**. Dentro do App, adicione os produtos:
- **WhatsApp**
- **Messenger**
- **Instagram** (aparece dentro das configurações do Messenger)

## 5. Migração do número de WhatsApp — LEIA COM ATENÇÃO ANTES DE FAZER
Hoje o número da loja é usado no **app comum do WhatsApp Business** (celular). Pra ele
funcionar com o sistema novo, ele precisa virar um número da **WhatsApp Business Platform**
(API oficial da Meta).

**O que muda depois da migração:** o número deixa de funcionar como um app de celular normal
— ele passa a ser controlado só por API (ou seja, só pelo sistema que estou construindo,
não mais digitando direto no WhatsApp do celular). Não tem volta fácil.

**Por isso: não faça esse passo ainda.** A Meta libera, de graça, um **número de teste**
pra qualquer App em desenvolvimento (aparece em WhatsApp → Introdução, dentro do App criado
no item 4) — vou usar esse número de teste pra construir e testar tudo (caixa de entrada,
"assumir conversa", resposta automática, aviso de pedido confirmado). Só depois de eu
confirmar que está tudo funcionando é que faz sentido migrar o número real — te aviso
quando chegar nessa etapa.

## 6. Usuário do Sistema + token permanente
Em Configurações do Negócio → Usuários → Usuários do Sistema:
1. Criar um Usuário do Sistema novo (ex: "sistema-atendimento").
2. Atribuir a ele acesso ao número de WhatsApp, à Página e à conta do Instagram (item 2/3).
3. Gerar um **token de acesso** — escolha duração **nunca expira** (token permanente) — com
   estas permissões marcadas:
   - `whatsapp_business_messaging`
   - `whatsapp_business_management`
   - `pages_messaging`
   - `pages_show_list`
   - `instagram_manage_messages`
   - `instagram_basic`
   - `business_management`

**Guarde esse token com cuidado** (ele vai virar um "segredo" no Supabase, nunca aparece
pra ninguém de fora) — se perder, dá pra gerar outro, mas o antigo para de funcionar.

## 7. Registrar o Webhook
No App → Webhooks → escolher o produto WhatsApp e também Página:
- **URL de callback**: eu te aviso a URL exata quando o Edge Function estiver publicado
  (formato `https://<seu-projeto>.supabase.co/functions/v1/meta-webhook`).
- **Verify Token**: invente uma senha qualquer (ex: uma frase aleatória) e me avise qual foi
  — ela vai pro Supabase como segredo `META_VERIFY_TOKEN` e precisa ser a mesma dos dois lados.
- Campos pra assinar: `messages` (WhatsApp) e `messages` + `messaging_postbacks` (Página —
  cobre Messenger e Instagram).

## 8. Revisão do App (App Review)
Usar `instagram_manage_messages` e `pages_messaging` de verdade (fora da sua própria conta
de desenvolvedor) exige que a Meta revise o App — normalmente pedem um vídeo curto mostrando
o uso real (ex: uma mensagem chegando e sendo respondida no seu sistema). Pode levar de
alguns dias a duas semanas, às vezes com pedido de ajuste no texto/vídeo. Isso é
**independente** do WhatsApp, que não exige revisão pros próprios números — pode fazer essa
submissão em paralelo enquanto eu termino o código.

## 9. Template da mensagem "Pedido confirmado"
Em WhatsApp Manager → Modelos de Mensagem → Criar modelo:
- Categoria: **Utilidade** (não "Marketing" — evita rejeição e é mais barato)
- Nome sugerido: `pedido_confirmado_v1`
- Texto sugerido (podemos ajustar juntos antes de enviar):
  > Oi {{1}}! Seu pedido foi confirmado e já está sendo preparado. Total: {{2}}. Obrigada
  > pela confiança! 💛
- Evite qualquer linguagem promocional/propaganda no texto — só confirmação transacional,
  senão a Meta rejeita.
- Aprovação costuma ser rápida (minutos a poucas horas), mas pode pedir ajuste.

## 10. O que me mandar quando tiver tudo isso
Depois de feito, me passe (por aqui mesmo, ou como segredo direto no Supabase se preferir
não digitar aqui):
- `WHATSAPP_PHONE_NUMBER_ID` (do número de teste, pra começar)
- `WHATSAPP_BUSINESS_ACCOUNT_ID`
- `FACEBOOK_PAGE_ID`
- `INSTAGRAM_ACCOUNT_ID`
- O token permanente do Usuário do Sistema (item 6)
- O Verify Token que você escolheu (item 7)
- Nome exato do template aprovado (item 9), quando aprovado

Com isso eu configuro os segredos no Supabase (`supabase secrets set ...`) e testamos de
ponta a ponta usando o número de teste, antes de pensar em migrar o número real (item 5).
