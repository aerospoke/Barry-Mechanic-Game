-- Distingue las piezas de trabajo (van a la mano de Barry, se llevan al auto)
-- de las decoraciones (se colocan en la sala como un objeto mas, ver
-- room_objects.sql). El "key" de una decoracion tiene que coincidir con un
-- kind de scripts/room_object_catalog.gd.
--
-- Ejecutar en el SQL Editor de Supabase (shop_items.sql ya debe haberse
-- corrido antes).

alter table public.shop_items
	add column if not exists tipo text not null default 'pieza'
	check (tipo in ('pieza', 'decoracion'));

insert into public.shop_items (key, name, price, tipo) values
	('estante_aceite', 'Estante de Aceite', 40, 'decoracion')
on conflict (key) do nothing;
