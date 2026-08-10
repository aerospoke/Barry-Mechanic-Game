-- Posicion personalizada de la PC dentro de la sala (se mueve desde el modo
-- de edicion: boton "Editar Sala" en el panel de perfil). NULL significa
-- "todavia no se movio": ahi el cliente calcula la posicion por defecto
-- (ver room.gd _colocar_pc()).
--
-- Ejecutar en el SQL Editor de Supabase. Requiere que sql/rooms.sql ya se
-- haya corrido antes (la tabla `rooms` tiene que existir).

alter table public.rooms
	add column if not exists pc_x double precision,
	add column if not exists pc_y double precision;
