# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A single-file admin/back-office web app for "JJ Solene" (a clothing/fashion business): inventory,
purchases, sales, sellers/commissions, customers, marketing, finance, invoices, and catalog
publishing. The entire application — HTML, CSS, and JS — lives in **`index.html`** (~2900 lines).
There is no build system, package manager, bundler, or test suite in this repo.

## Running / developing

- There is nothing to install or build. Open `index.html` directly in a browser, or serve the
  directory with any static file server (e.g. `python -m http.server`) if you need it served over
  `http://` rather than `file://`.
- All edits happen directly in `index.html`. Verify changes by reloading the file in a browser —
  there is no linter or automated test suite to run.
- The app talks to a live Supabase project over the network (see below), so testing requires
  network access and valid Supabase credentials.

## Architecture

**Backend:** [Supabase](https://supabase.com) (Postgres + Auth + Storage), loaded from the
`@supabase/supabase-js@2` CDN script. There is no server-side code in this repo — all data access
happens client-side through the Supabase JS client (`SUPA`), with every call wrapped in the `q()`
helper (`index.html:225`), which unwraps `{ data, error }`, toasts on error, and rethrows.

- Default project credentials are hardcoded (`DEFAULT_SB_URL` / `DEFAULT_SB_ANON`, `index.html:207-208`)
  so the app works out of the box on any device. The anon key is safe to expose because access is
  gated by Postgres Row Level Security policies on the Supabase project, not by hiding the key.
- A user can instead paste their own project's URL/anon key on the "Conectar" screen
  (`renderConnectScreen`); these are cached in `localStorage` (`jjsolene_sb_url` / `jjsolene_sb_anon`).
- The Postgres schema itself is **not** version-controlled in this repo — it lives in the Supabase
  project. Comments in the code reference external SQL files (`schema.sql`, `migracao-fase2.sql`)
  that the user runs manually in the Supabase SQL editor; don't assume these files exist locally.
- Tables used (via `SUPA.from(...)`): `settings`, `categories`, `products`, `product_media`,
  `product_sizes`, `purchases`, `purchase_items`, `sales`, `sale_items`, `orders`, `sellers`,
  `commission_payments`, `customers`, `banners`, `gift_rules`, `coupons`, `waitlist`, `finance`,
  `recurring_expenses`, `invoices`.

**App shell / navigation:** No client-side router or URL state. The sidebar has one `.nav-item` per
tab (`data-tab="..."`); `showTab(name)` toggles visibility of the matching `#tab-<name>` panel and
calls `renderTab(name)`, which dispatches to one `render*()` function per section (`renderDashboard`,
`renderPedidos`, `renderEstoque`, `renderCompras`, `renderVendas`, `renderVendedores`,
`renderClientes`, `renderMarketing`, `renderFinanceiro`, `renderNF`, `renderCatalogoTab`,
`renderConfig`). Each `render*` function fetches its own data and rebuilds its panel's `innerHTML`
from scratch — there's no component/virtual-DOM layer, just string-built HTML plus inline
`onclick="..."` handlers wired to global functions.

**Auth flow:** `boot()` (bottom of file) → `initClient()` creates the Supabase client and calls
`checkSession()` → if no session, `renderLoginScreen()` (Supabase Auth email/password); if
connection info is missing entirely, `renderConnectScreen()` is shown first. On success,
`enterApp()` reveals `#appRoot` and loads the dashboard.

**Public catalog generator:** The "Catálogo" tab (`renderCatalogoTab` / `generateCatalog`,
`index.html:1693+`) does not publish anything itself — `buildCatalogHTML()` stitches together
`CATALOG_CSS` and `CATALOG_JS` (large template strings embedded later in the file) into a complete,
self-contained HTML document, which the browser downloads as `catalogo-jjsolene.html`. The user
hosts that file separately (e.g. GitHub Pages); it embeds the same Supabase URL/anon key and reads
products/stock/prices live from the same database, so it stays in sync without needing to be
regenerated on data changes — only when the visual template (`CATALOG_CSS`/`CATALOG_JS`) itself
changes. This generated file is a build artifact, not something tracked in this repo.

## Conventions

- UI copy, all code comments, and variable/data conventions (e.g. date formatting via
  `toLocaleDateString('pt-BR')`, currency via `fmtMoney`) are in Brazilian Portuguese. Keep new UI
  text and comments in pt-BR for consistency.
- Sections of the script are separated by `/* ===== ... ===== */` banner comments — keep new
  top-level functionality organized the same way rather than interleaving unrelated logic.
- Money values are stored/handled as plain numbers and formatted for display only via `fmtMoney`;
  don't format at the data layer.
