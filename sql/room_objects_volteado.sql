-- Muebles girados en el modo edicion de la sala (boton "Girar"). Con una
-- sola imagen por mueble, girarlo es espejarlo: ver WorldObject.volteado en
-- scripts/world_object.gd.
--
-- Ejecutar en el SQL Editor de Supabase (room_objects.sql ya debe haberse
-- corrido antes).

alter table public.room_objects add column if not exists volteado boolean not null default false;
