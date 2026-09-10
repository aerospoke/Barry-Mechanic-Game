-- Da de alta en el catalogo `tutorials` el paso a paso del nuevo minijuego
-- de cerrajeria (ver scenes/mini_game_keys.gd, ID_TUTORIAL = "minigame_keys").
-- Sin esta fila, marcar_tutorial_visto() falla en silencio por la foreign
-- key y el tutorial vuelve a salir siempre.
--
-- Ejecutar en el SQL Editor de Supabase (tutorials.sql ya debe haberse
-- corrido antes).

insert into public.tutorials (id, name) values
	('minigame_keys', 'Minijuego: cerrajeria')
on conflict (id) do nothing;
