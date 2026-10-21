-- Equipo de sonido profesional: suena igual de fuerte en TODO el taller (el
-- comun solo se escucha bien cerca). Es la mejora del equipo comun: al
-- comprarlo lo reemplaza en el mismo lugar, nunca hay dos. Un premio para
-- juntar plata trabajando. Ver "radio_pro" en scripts/room_object_catalog.gd
-- y scripts/radio_equipo.gd.
--
-- Ejecutar en el SQL Editor de Supabase (shop_items_descripcion.sql ya debe
-- haberse corrido antes).

insert into public.shop_items (key, name, price, tipo, description) values
	('radio_pro', 'Equipo de sonido PRO', 800, 'decoracion',
	 'Torre profesional con luces LED: ¡suena a todo volumen en TODO el taller! Trabaja, junta y que retumbe el garaje.')
on conflict (key) do nothing;
