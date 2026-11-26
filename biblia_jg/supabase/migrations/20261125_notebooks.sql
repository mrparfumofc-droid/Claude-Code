-- Cadernos de anotação à mão (Estudo > Caderno). Aplicado no projeto biblia-jg em 25/11/2026.
-- Cada usuário só enxerga os próprios cadernos. As imagens coladas nas folhas ficam no bucket
-- privado "livros", em <id do usuário>/cadernos/<id do caderno>/<arquivo> (políticas já existentes).

create table if not exists public.notebooks (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  meta jsonb not null default '{}'::jsonb,       -- título, capa, pasta, ordem das páginas (NbBook.toJson)
  deleted boolean not null default false,        -- apagado em algum aparelho (os outros apagam ao sincronizar)
  updated_at timestamptz not null default now()
);

create table if not exists public.notebook_pages (
  notebook_id uuid not null references public.notebooks(id) on delete cascade,
  page_id text not null,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  data jsonb not null default '{}'::jsonb,       -- modelo, papel e elementos da página (NbPage.toJson)
  updated_at timestamptz not null default now(),
  primary key (notebook_id, page_id)
);

create index if not exists notebooks_user_idx on public.notebooks (user_id);
create index if not exists notebook_pages_user_idx on public.notebook_pages (user_id);

alter table public.notebooks enable row level security;
alter table public.notebook_pages enable row level security;

create policy notebooks_own on public.notebooks for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy notebook_pages_own on public.notebook_pages for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

grant select, insert, update, delete on public.notebooks to authenticated;
grant select, insert, update, delete on public.notebook_pages to authenticated;
