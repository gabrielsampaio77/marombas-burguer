-- =====================================================================
-- MAROMBAS BURGER – BANCO DE DADOS (Supabase / PostgreSQL)
-- Como usar: Supabase → SQL Editor → New query → cole TUDO → Run.
-- Pode rodar de novo sem perder dados (não apaga nada).
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) ADMINISTRADORES  >>> TROQUE O E-MAIL ABAIXO PELO DO DONO <<<
--    Só os e-mails desta tabela conseguem editar pelo painel.
-- ---------------------------------------------------------------------
create table if not exists public.admins (
  email text primary key
);
insert into public.admins (email) values ('afiliado.aliexpress057@gmail.com')
on conflict do nothing;

alter table public.admins enable row level security;   -- ninguém lê pela internet

create or replace function public.is_admin()
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from public.admins
    where lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );
$$;
revoke all on public.admins from anon, authenticated;
revoke execute on function public.is_admin() from anon, public;
grant execute on function public.is_admin() to authenticated;

-- ---------------------------------------------------------------------
-- 2) TABELAS
-- ---------------------------------------------------------------------
create table if not exists public.configuracoes (
  id            int primary key default 1 check (id = 1),   -- sempre 1 linha
  nome          text not null default 'Marombas Burger',
  whatsapp      text not null,                               -- 55 + DDD + número
  telefone      text,
  endereco      text,
  cidade        text,
  taxa_entrega  numeric(10,2),                               -- null = a combinar
  horario       text,
  atualizado_em timestamptz not null default now()
);

create table if not exists public.categorias (
  id     text primary key,
  nome   text not null,
  ordem  int  not null default 0,
  ativo  boolean not null default true
);

create table if not exists public.produtos (
  id            text primary key default gen_random_uuid()::text,
  categoria_id  text not null references public.categorias(id) on update cascade on delete restrict,
  nome          text not null,
  descricao     text,
  spec          text,                                         -- ex.: "Carga: 2 × 150g"
  preco         numeric(10,2) not null check (preco >= 0),
  badge         text,                                         -- selo: "Mais pedido"
  imagem_url    text,                                         -- foto enviada pelo painel
  arte          jsonb,                                        -- ilustração usada sem foto
  ativo         boolean not null default true,                -- false = esgotado/oculto
  ordem         int not null default 0,
  criado_em     timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);
create index if not exists produtos_categoria_idx on public.produtos (categoria_id, ordem);

grant select on public.configuracoes, public.categorias, public.produtos to anon, authenticated;
grant insert, update, delete on public.configuracoes, public.categorias, public.produtos to authenticated;

-- ---------------------------------------------------------------------
-- 3) SEGURANÇA (Row Level Security)
--    Qualquer visitante LÊ o cardápio. Só administradores ALTERAM.
-- ---------------------------------------------------------------------
alter table public.configuracoes enable row level security;
alter table public.categorias    enable row level security;
alter table public.produtos      enable row level security;

drop policy if exists "config: leitura publica" on public.configuracoes;
drop policy if exists "config: admin altera"    on public.configuracoes;
create policy "config: leitura publica" on public.configuracoes for select to anon, authenticated using (true);
create policy "config: admin altera"    on public.configuracoes for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "categorias: leitura publica" on public.categorias;
drop policy if exists "categorias: admin altera"    on public.categorias;
create policy "categorias: leitura publica" on public.categorias for select to anon, authenticated using (ativo);
create policy "categorias: admin altera"    on public.categorias for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "produtos: leitura publica" on public.produtos;
drop policy if exists "produtos: admin altera"    on public.produtos;
create policy "produtos: leitura publica" on public.produtos for select to anon, authenticated using (ativo);
create policy "produtos: admin altera"    on public.produtos for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- ---------------------------------------------------------------------
-- 4) FOTOS (Storage) – pasta pública "produtos", até 5 MB por imagem
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('produtos', 'produtos', true, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;

drop policy if exists "fotos: admin envia"  on storage.objects;
drop policy if exists "fotos: admin troca"  on storage.objects;
drop policy if exists "fotos: admin apaga"  on storage.objects;
drop policy if exists "fotos: admin lista"  on storage.objects;
create policy "fotos: admin lista" on storage.objects for select to authenticated
  using (bucket_id = 'produtos' and public.is_admin());
create policy "fotos: admin envia" on storage.objects for insert to authenticated
  with check (bucket_id = 'produtos' and public.is_admin());
create policy "fotos: admin troca" on storage.objects for update to authenticated
  using (bucket_id = 'produtos' and public.is_admin());
create policy "fotos: admin apaga" on storage.objects for delete to authenticated
  using (bucket_id = 'produtos' and public.is_admin());

-- ---------------------------------------------------------------------
-- 5) CARDÁPIO REAL (07/11/2026) – edite pelo painel
-- ---------------------------------------------------------------------
insert into public.configuracoes (id, nome, whatsapp, telefone, endereco, cidade, taxa_entrega, horario)
values (1, 'Marombas Burger', '5569999293397', '(69) 99929-3397', 'Rua Aruba, 8739 – Socialista',
        'Porto Velho – RO, CEP 78910-521', null, 'Abre às 16h')
on conflict (id) do nothing;

insert into public.categorias (id, nome, ordem, ativo) values
  ('burgers', 'Hambúrgueres', 0, true),
  ('combos', 'Combos', 1, true),
  ('porcoes', 'Porções de batata', 2, true),
  ('bebidas', 'Bebidas', 3, true),
  ('adicionais', 'Adicionais', 4, true)
on conflict (id) do nothing;

insert into public.produtos (id, categoria_id, nome, descricao, spec, preco, badge, imagem_url, arte, ativo, ordem) values
  ('marombinha', 'burgers', 'Marombinha', 'Hambúrguer de 180g, muçarela, requeijão e cebola caramelizada.', '180g', 26.80, null, 'img/fotos/marombinha.webp', '{"type": "burger", "patties": 1, "cheese": "cheddar"}'::jsonb, true, 0),
  ('maromba-rib', 'burgers', 'Maromba Rib', 'Hambúrguer de 150g, costela desfiada, cebola caramelizada e requeijão.', '150g + costela', 30.00, null, 'img/fotos/maromba-rib.webp', '{"type": "burger", "patties": 1, "cheese": "cheddar"}'::jsonb, true, 1),
  ('cupim-musculoso', 'burgers', 'Cupim Musculoso', 'Hambúrguer artesanal com cupim desfiado.', 'Cupim desfiado', 30.00, null, 'img/fotos/cupim-musculoso.webp', '{"type": "burger", "patties": 1, "cheese": "cheddar"}'::jsonb, true, 2),
  ('insano', 'burgers', 'Insano', '2 carnes de 100g, 2x cheddar, 2x banana e 2x bacon. Uma combinação para quem tem fome de verdade!', '2 × 100g', 42.28, '2 carnes', 'img/fotos/insano.webp', '{"type": "burger", "patties": 2, "cheese": "cheddar", "bacon": true}'::jsonb, true, 3),
  ('king-bacon', 'burgers', 'King Bacon', 'Hambúrguer de 100g, requeijão, molho quatro queijos e muito bacon.', '100g', 25.00, null, 'img/fotos/king-bacon.webp', '{"type": "burger", "patties": 1, "cheese": "white", "bacon": true}'::jsonb, true, 4),
  ('pituxo', 'burgers', 'Pituxo', '2 smash burgers com bastante cheddar e requeijão.', '2 smash', 18.00, 'Smash', 'img/fotos/pituxo.webp', '{"type": "burger", "patties": 1, "cheese": "cheddar"}'::jsonb, true, 5),
  ('classic-burger', 'burgers', 'Classic Burger', null, null, 0.00, null, 'img/fotos/classic-burger.webp', '{"type": "burger", "patties": 1, "cheese": "cheddar"}'::jsonb, false, 6),
  ('gym-bro', 'combos', 'Gym Bro', '2 Maromba Rib ou Cupim Musculoso, Batata Iniciante e 2 refrigerantes em lata. Diga nas observações qual lanche você quer.', 'Para 2 pessoas', 69.99, 'Para 2', 'img/ilustrativas/gym-bro.webp', '{"type": "combo", "burger": {"patties": 1, "cheese": "white", "onion": "caramel"}}'::jsonb, true, 0),
  ('marombas-love', 'combos', 'Marombas Love', '2 Insanos, Batata Iniciante e 2 refrigerantes em lata.', 'Para 2 pessoas', 90.00, 'Para 2', 'img/ilustrativas/marombas-love.webp', '{"type": "combo", "burger": {"patties": 2, "cheese": "cheddar", "bacon": true}}'::jsonb, true, 1),
  ('batata-iniciante', 'porcoes', 'Batata Iniciante', 'Porção de 150g de batatas.', '150g', 10.00, null, 'img/ilustrativas/batata-iniciante.webp', '{"type": "fries"}'::jsonb, true, 0),
  ('batata-bombada', 'porcoes', 'Batata Bombada', '300g de batata, bacon e molho cheddar.', '300g', 27.00, null, 'img/ilustrativas/batata-bombada-v2.webp', '{"type": "fries", "cheddar": true}'::jsonb, true, 1),
  ('batata-maromba', 'porcoes', 'Batata Maromba', '300g de batata, costela desfiada e requeijão.', '300g', 32.00, null, 'img/ilustrativas/batata-maromba-v2.webp', '{"type": "fries"}'::jsonb, true, 2),
  ('refri-lata', 'bebidas', 'Refrigerante lata', 'Lata 350ml. Informe o sabor nas observações.', 'Lata', 8.00, null, 'img/ilustrativas/refri-lata-v2.webp', '{"type": "can"}'::jsonb, true, 0),
  ('add-hamburguer', 'adicionais', 'Adicional de hambúrguer', null, null, 8.00, null, null, '{"type": "burger", "patties": 1, "cheese": "cheddar"}'::jsonb, true, 0),
  ('add-banana', 'adicionais', 'Adicional de banana', null, null, 3.00, null, null, '{"type": "burger", "patties": 1, "cheese": "cheddar"}'::jsonb, true, 1),
  ('add-mucarela', 'adicionais', 'Adicional de muçarela', null, null, 2.00, null, null, '{"type": "burger", "patties": 1, "cheese": "cheddar"}'::jsonb, true, 2),
  ('add-cheddar', 'adicionais', 'Adicional de cheddar', null, null, 3.00, null, null, '{"type": "burger", "patties": 1, "cheese": "cheddar"}'::jsonb, true, 3),
  ('add-requeijao', 'adicionais', 'Adicional de requeijão', null, null, 3.00, null, null, '{"type": "burger", "patties": 1, "cheese": "cheddar"}'::jsonb, true, 4),
  ('add-queijo-coalho', 'adicionais', 'Adicional de queijo coalho', null, null, 3.00, null, null, '{"type": "burger", "patties": 1, "cheese": "cheddar"}'::jsonb, true, 5),
  ('add-bacon', 'adicionais', 'Adicional de bacon', null, null, 3.00, null, null, '{"type": "burger", "patties": 1, "cheese": "cheddar"}'::jsonb, true, 6)
on conflict (id) do nothing;

-- ---------------------------------------------------------------------
-- 6) PRAZO DE RESPOSTA NO WHATSAPP
-- ---------------------------------------------------------------------
alter table public.configuracoes
  add column if not exists tempo_resposta text;
update public.configuracoes set tempo_resposta = coalesce(tempo_resposta, '15 minutos') where id = 1;
