-- =====================================================================
-- Importação em massa do Phibo (produtos/estoque + clientes) — schema
-- Rode este arquivo inteiro no SQL Editor do Supabase (projeto JJ Solene),
-- uma única vez, antes de usar o importador em Configurações.
-- =====================================================================

-- fornecedores.cnpj: usado pra casar/criar fornecedor automaticamente durante
-- o import de estoque (o Phibo identifica o fornecedor pelo CNPJ, não por nome).
-- Guardado só com dígitos (sem máscara), igual telefone/CEP/CPF em customers.
alter table fornecedores
  add column if not exists cnpj text;

-- evita duplicar fornecedor se o mesmo arquivo (ou uma versão atualizada dele)
-- for importado de novo — fornecedores cadastrados manualmente sem CNPJ continuam
-- podendo existir sem cair nessa restrição (índice parcial)
create unique index if not exists fornecedores_cnpj_uq
  on fornecedores(cnpj) where cnpj is not null;

-- products.fornecedor_id: vincula o produto ao fornecedor resolvido/criado pelo
-- CNPJ durante o import — hoje não existia nenhum vínculo produto→fornecedor.
alter table products
  add column if not exists fornecedor_id uuid references fornecedores(id);
