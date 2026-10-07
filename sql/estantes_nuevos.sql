-- Cuatro estantes nuevos, cada uno con su pieza, su trabajo y su minijuego:
--
--   estante (shop_items.key) | trabajo (WorkList.key) | minijuego
--   cables                   | electric_fix           | scenes/mini_game_cables.gd (laser por el circuito)
--   tools                    | organize_tools         | scenes/mini_game_herramientas.gd (siluetas)
--   air                      | inflate_tires          | scenes/mini_game_inflar.gd (compresor)
--   paint                    | paint_job              | scenes/mini_game_pintura.gd (retocar pintura)
--
-- El key del estante tiene que coincidir con su kind en
-- scripts/room_object_catalog.gd y con la pieza en scripts/shop_catalog.gd;
-- el key del trabajo, con MINIGAMES en scripts/movement_script.gd.
--
-- Ejecutar en el SQL Editor de Supabase (shop_items_decoracion.sql,
-- worklist_key.sql y tutorials.sql ya deben haberse corrido antes).

-- 1) Estantes en la tienda (se compran una vez y se colocan en la sala).
insert into public.shop_items (key, name, price, tipo) values
	('cables', 'Estante de Corriente', 40, 'decoracion'),
	('tools', 'Banco de Herramientas', 40, 'decoracion'),
	('air', 'Compresor de Aire', 40, 'decoracion'),
	('paint', 'Estante de Pinturas', 40, 'decoracion')
on conflict (key) do nothing;

-- 2) Trabajos nuevos. electric_fix ya existia (ver worklist_key.sql). Los
-- valores de precio/pago/puntos se copian del cambio de aceite para no
-- adivinar el formato de la tabla; despues se ajustan a mano en el editor.
insert into public."WorkList" (name, price, payment, points, key)
select v.name, w.price, w.payment, w.points, v.key
from public."WorkList" w
cross join (values
	('Organizar herramientas', 'organize_tools'),
	('Inflar llantas', 'inflate_tires'),
	('Retocar pintura', 'paint_job')
) as v(name, key)
where w.key = 'change_oil'
on conflict (key) do nothing;

-- 3) Tutoriales de cada minijuego (una vez por cuenta).
insert into public.tutorials (id, name) values
	('minigame_cables', 'Minijuego: reparacion electrica'),
	('minigame_herramientas', 'Minijuego: banco de herramientas'),
	('minigame_inflar', 'Minijuego: inflar llantas'),
	('minigame_pintura', 'Minijuego: retocar pintura')
on conflict (id) do nothing;
