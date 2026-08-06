-- =====================================================================
-- Filtros do catálogo público — RPC "mais vendidos" (somente leitura)
-- Rode este arquivo inteiro no SQL Editor do Supabase (projeto JJ Solene).
-- Não altera nenhuma tabela existente; cria só uma função nova.
-- =====================================================================

-- Retorna a soma de itens vendidos por produto (sale_items), sem nenhum
-- dado de cliente (nome/telefone) — seguro pra expor ao catálogo público
-- (chave anon), que hoje não tem nenhum acesso a sales/sale_items.
create or replace function get_bestseller_counts()
returns table(product_id uuid, total_sold bigint)
language sql
security definer
set search_path = public
stable
as $$
  select si.product_id, sum(si.qty)::bigint as total_sold
  from sale_items si
  group by si.product_id;
$$;

-- O catálogo público acessa via chave anon (sem login) — sem este grant,
-- a chamada sb.rpc('get_bestseller_counts') falha por permissão mesmo a
-- função sendo security definer.
grant execute on function get_bestseller_counts() to anon, authenticated;
