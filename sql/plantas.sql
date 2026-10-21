-- Diez plantas en maceta para decorar el taller (ver objetos/plantas/ y
-- "planta_*" en scripts/room_object_catalog.gd). El key de cada una coincide
-- con su kind en el catalogo.
--
-- Ejecutar en el SQL Editor de Supabase (shop_items_descripcion.sql ya debe
-- haberse corrido antes).

insert into public.shop_items (key, name, price, tipo, description) values
	('planta_monstera', 'Planta: Monstera', 60, 'decoracion',
	 'La reina de las plantas de interior, con sus hojas agujereadas. Le da un toque selvatico al taller.'),
	('planta_cactus', 'Planta: Cactus', 25, 'decoracion',
	 'Duro como un mecanico: casi no necesita agua. Y tiene una flor rosada en la punta.'),
	('planta_suculenta', 'Planta: Suculenta', 20, 'decoracion',
	 'Chiquita y redonda, perfecta para el escritorio o al lado de la PC.'),
	('planta_palmera', 'Planta: Palmera Areca', 70, 'decoracion',
	 'Una palmera en el taller: trae vibras de playa mientras cambias el aceite.'),
	('planta_sansevieria', 'Planta: Lengua de Suegra', 40, 'decoracion',
	 'La lengua de suegra: alta, rayada y casi indestructible.'),
	('planta_helecho', 'Planta: Helecho', 35, 'decoracion',
	 'Helecho frondoso que cae para todos lados. Llena cualquier rincon.'),
	('planta_ficus', 'Planta: Ficus', 80, 'decoracion',
	 'Arbolito de hojas verdes y tronco firme. Para un taller con sombrita.'),
	('planta_bonsai', 'Planta: Bonsai', 120, 'decoracion',
	 'Un arbol en miniatura, para los mecanicos con paciencia de maestro.'),
	('planta_girasoles', 'Planta: Girasoles', 45, 'decoracion',
	 'Tres girasoles que alegran el dia de cualquiera.'),
	('planta_bambu', 'Planta: Bambu de la Suerte', 50, 'decoracion',
	 'Bambu de la suerte: dicen que trae buenos trabajos al taller.')
on conflict (key) do nothing;
