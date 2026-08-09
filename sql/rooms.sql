-- Salas creadas por los jugadores (estilo Habbo).
--
-- Solo se guarda el nombre y el estilo: la geometría de la sala se genera en
-- el cliente a partir del estilo (scripts/room_styles.gd), así que no hay que
-- persistir 2500 baldosas por sala.
--
-- Ejecutar en el SQL Editor de Supabase.

create table if not exists public.rooms (
	id          uuid primary key default gen_random_uuid(),
	owner       uuid not null references auth.users (id) on delete cascade,
	name        text not null check (char_length(name) between 1 and 24),
	style       text not null,
	created_at  timestamptz not null default now()
);

create index if not exists rooms_owner_idx on public.rooms (owner);

alter table public.rooms enable row level security;

-- Las salas se ven entre jugadores (la idea es poder visitarlas), pero solo
-- las toca su dueño.
create policy "rooms_select_all"
	on public.rooms for select
	to authenticated
	using (true);

create policy "rooms_insert_own"
	on public.rooms for insert
	to authenticated
	with check (auth.uid() = owner);

create policy "rooms_update_own"
	on public.rooms for update
	to authenticated
	using (auth.uid() = owner)
	with check (auth.uid() = owner);

create policy "rooms_delete_own"
	on public.rooms for delete
	to authenticated
	using (auth.uid() = owner);
