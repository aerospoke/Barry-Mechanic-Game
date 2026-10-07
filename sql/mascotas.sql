-- Mascotas del taller: se compra un guacal en la tienda, se coloca en la
-- sala y despues se elige que mascota sale de el (ver
-- scripts/pet_catalog.gd y scripts/pet_picker.gd).
--
-- room_objects.variant es generico: guarda "que version" de un objeto se
-- eligio. Para el guacal es el id de la mascota ('nami'); otros objetos lo
-- pueden usar mas adelante (un color, un modelo...) sin otra migracion.
--
-- Ejecutar en el SQL Editor de Supabase (room_objects.sql y
-- shop_items_descripcion.sql ya deben haberse corrido antes).

alter table public.room_objects add column if not exists variant text;

insert into public.shop_items (key, name, price, tipo, description) values
	('guacal', 'Comprar mascota', 60, 'decoracion',
	 'Un guacal para tu taller. Ponlo en la sala y elige que mascota vive en el: ¡te acompañara mientras trabajas!')
on conflict (key) do nothing;
