-- Equipo de sonido para la sala: gratis en la tienda. La musica del taller
-- sale solo de el (ver scripts/radio_equipo.gd y scripts/radio_panel.gd).
--
-- Ejecutar en el SQL Editor de Supabase (shop_items_descripcion.sql ya debe
-- haberse corrido antes).

insert into public.shop_items (key, name, price, tipo, description) values
	('radio', 'Equipo de sonido', 0, 'decoracion',
	 '¡Gratis! Ponlo en tu taller y que suene la musica: prendelo, cambia de emisora y sube el volumen desde el mismo equipo.')
on conflict (key) do nothing;
