-- Da de alta en el catalogo `tutorials` el paso a paso del minijuego de
-- reciclaje (ver scenes/mini_game_reciclaje.gd, ID_TUTORIAL =
-- "minigame_reciclaje"). Sin esta fila, marcar_tutorial_visto() falla en
-- silencio por la foreign key y el tutorial vuelve a salir siempre.
--
-- Ejecutar en el SQL Editor de Supabase (tutorials.sql ya debe haberse
-- corrido antes).

insert into public.tutorials (id, name) values
	('minigame_reciclaje', 'Minijuego: reciclaje del taller')
on conflict (id) do nothing;
