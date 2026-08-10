-- Objetos colocados dentro de una sala (la PC, y lo que se agregue despues:
-- sofa, planta, decoracion...). Una fila por objeto, en vez de columnas
-- especificas por tipo en `rooms` (como era `pc_x`/`pc_y`) — asi un objeto
-- nuevo no necesita ninguna migracion, solo una entrada en el catalogo del
-- cliente (ver scripts/room_object_catalog.gd) y filas en esta tabla.
--
-- Ejecutar en el SQL Editor de Supabase (rooms ya debe existir, ver
-- rooms.sql).

create table if not exists public.room_objects (
	id         uuid primary key default gen_random_uuid(),
	room_id    uuid not null references public.rooms (id) on delete cascade,
	kind       text not null check (char_length(kind) between 1 and 40),
	x          double precision not null,
	y          double precision not null,
	created_at timestamptz not null default now()
);

create index if not exists room_objects_room_idx on public.room_objects (room_id);

alter table public.room_objects enable row level security;

-- Los objetos se ven entre jugadores (igual que las salas), pero solo el
-- dueño de la sala los puede crear/mover/borrar.
create policy "room_objects_select_all"
	on public.room_objects for select
	to authenticated
	using (true);

create policy "room_objects_insert_own"
	on public.room_objects for insert
	to authenticated
	with check (exists (
		select 1 from public.rooms r where r.id = room_id and r.owner = auth.uid()
	));

create policy "room_objects_update_own"
	on public.room_objects for update
	to authenticated
	using (exists (
		select 1 from public.rooms r where r.id = room_id and r.owner = auth.uid()
	));

create policy "room_objects_delete_own"
	on public.room_objects for delete
	to authenticated
	using (exists (
		select 1 from public.rooms r where r.id = room_id and r.owner = auth.uid()
	));

-- Se agregan por si rooms_pc_position.sql no se corrio todavia: asi este
-- script no depende de haber corrido ese antes.
alter table public.rooms add column if not exists pc_x double precision;
alter table public.rooms add column if not exists pc_y double precision;

-- Migra las posiciones de PC que ya se hayan guardado con el sistema viejo,
-- para no perder lo que el jugador ya movio.
insert into public.room_objects (room_id, kind, x, y)
select id, 'pc', pc_x, pc_y
from public.rooms
where pc_x is not null and pc_y is not null;

alter table public.rooms drop column if exists pc_x;
alter table public.rooms drop column if exists pc_y;
