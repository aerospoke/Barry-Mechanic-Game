-- Nivel de la caneca de basura del taller (ver Supabase.CAPACIDAD_BASURA en
-- supabase.gd). Cada trabajo completado suma 1 (sin pasarse de la
-- capacidad); al llenarse se juega el minijuego de reciclaje
-- (scenes/mini_game_reciclaje.gd), que la vuelve a 0.
--
-- Es por jugador, no por sala: todas las canecas muestran el mismo nivel.
--
-- Ejecutar en el SQL Editor de Supabase: sin esta columna el perfil carga
-- igual, pero falla guardar al completar un trabajo o vaciar la caneca.

alter table public.profiles add column if not exists trash_level integer not null default 0;
