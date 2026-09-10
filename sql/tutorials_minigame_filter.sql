-- Da de alta en el catalogo `tutorials` el paso a paso del minijuego de
-- cambio de filtro de aire (ver scenes/mini_game_filter.gd,
-- ID_TUTORIAL = "minigame_filter"). Sin esta fila, marcar_tutorial_visto()
-- falla en silencio por la foreign key y el tutorial vuelve a salir siempre.
--
-- Ejecutar en el SQL Editor de Supabase (tutorials.sql ya debe haberse
-- corrido antes).

insert into public.tutorials (id, name) values
	('minigame_filter', 'Minijuego: cambio de filtro de aire')
on conflict (id) do nothing;
