-- Posicion de la TV de "hazte Gold" a lo largo de la pared (ver
-- sql/rooms_gold.sql para el flag owner_gold que la muestra/oculta).
-- Es una fraccion (0.0 = pegada a una punta de la pared, 1.0 = pegada a la
-- otra, 0.5 = centro) en vez de pixeles, asi no importa el tamaño de la
-- sala. El jugador la mueve arrastrandola en modo edicion (ver room.gd
-- _guardar_pos_banner_gold).
--
-- Ejecutar en el SQL Editor de Supabase (rooms.sql ya debe haberse corrido
-- antes).

alter table public.rooms
	add column if not exists gold_banner_t double precision not null default 0.5
	check (gold_banner_t >= 0.0 and gold_banner_t <= 1.0);
