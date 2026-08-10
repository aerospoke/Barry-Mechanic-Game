-- Marca la sala principal de cada jugador: al iniciar sesion se entra directo
-- a esa sala (ver Supabase.redirigir_tras_login()) en vez de al taller. Se
-- pone en true automaticamente para la primera sala que crea cada cuenta
-- (ver crear_sala_ui.gd); las que se crean despues desde la PC quedan en
-- false.
--
-- Ejecutar en el SQL Editor de Supabase (rooms ya debe existir, ver
-- rooms.sql).

alter table public.rooms
	add column if not exists is_main boolean not null default false;

-- Como mucho una sala principal por jugador.
create unique index if not exists rooms_owner_main_uidx
	on public.rooms (owner)
	where (is_main);
