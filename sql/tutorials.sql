-- Catalogo de tutoriales (uno para la bienvenida, y a futuro uno por cada
-- minijuego) + registro de cuales ya vio cada usuario. Mismo patron que
-- WorkList/usersWorks: el catalogo vive en la base para poder agregar
-- tutoriales nuevos sin tocar codigo mas que la pantalla que los muestra.
--
-- Ejecutar en el SQL Editor de Supabase.

create table if not exists public.tutorials (
	id   text primary key,
	name text not null
);

alter table public.tutorials enable row level security;

drop policy if exists "tutorials_select_all" on public.tutorials;
create policy "tutorials_select_all"
	on public.tutorials for select
	to authenticated
	using (true);

insert into public.tutorials (id, name) values
	('bienvenida', 'Bienvenida al juego'),
	('minigame_oil', 'Minijuego: cambio de aceite')
on conflict (id) do nothing;

-- Nombre con mayusculas (comillas) para que coincida exacto con como lo pide
-- el cliente via PostgREST, igual que "WorkList"/"usersWorks".
create table if not exists public."userTutorials" (
	id           uuid primary key default gen_random_uuid(),
	"userId"     uuid not null references auth.users (id) on delete cascade,
	"tutorialId" text not null references public.tutorials (id) on delete cascade,
	visto        boolean not null default true,
	"seenAt"     timestamptz not null default now(),
	unique ("userId", "tutorialId")
);

alter table public."userTutorials" enable row level security;

-- Cada uno ve y marca solo lo suyo.
drop policy if exists "userTutorials_select_own" on public."userTutorials";
create policy "userTutorials_select_own"
	on public."userTutorials" for select
	to authenticated
	using (auth.uid() = "userId");

drop policy if exists "userTutorials_insert_own" on public."userTutorials";
create policy "userTutorials_insert_own"
	on public."userTutorials" for insert
	to authenticated
	with check (auth.uid() = "userId");

drop policy if exists "userTutorials_update_own" on public."userTutorials";
create policy "userTutorials_update_own"
	on public."userTutorials" for update
	to authenticated
	using (auth.uid() = "userId")
	with check (auth.uid() = "userId");
