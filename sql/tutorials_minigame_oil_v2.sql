-- Da de alta en el catalogo `tutorials` el paso a paso del minijuego de
-- aceite rediseñado (atrapar gotas, ver scenes/mini_game_oil.gd,
-- ID_TUTORIAL = "minigame_oil_v2"). Es un id nuevo a proposito: quien ya vio
-- el tutorial viejo ("minigame_oil") tiene que ver las reglas nuevas.
-- Sin esta fila, marcar_tutorial_visto() falla en silencio por la foreign
-- key y el tutorial vuelve a salir siempre.
--
-- Ejecutar en el SQL Editor de Supabase (tutorials.sql ya debe haberse
-- corrido antes).

insert into public.tutorials (id, name) values
	('minigame_oil_v2', 'Minijuego: cambio de aceite (atrapar gotas)')
on conflict (id) do nothing;
