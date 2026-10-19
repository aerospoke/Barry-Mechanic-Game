-- Ventana estilo Habbo (cielo con nubes animadas) que se cuelga en la pared
-- de la sala. Se guarda en room_objects como cualquier objeto, pero en vez
-- de una posicion de piso usa x = posicion a lo largo de la pared (0..1) e
-- y = que pared (0 o 1). Ver scripts/ventana_pared.gd y room.gd.
--
-- Ejecutar en el SQL Editor de Supabase (shop_items_descripcion.sql ya debe
-- haberse corrido antes).

insert into public.shop_items (key, name, price, tipo, description) values
	('ventana', 'Ventana', 30, 'decoracion',
	 'Una ventana para tu taller con vista al cielo: ¡mira pasar las nubes mientras trabajas! Se cuelga en la pared.')
on conflict (key) do nothing;
