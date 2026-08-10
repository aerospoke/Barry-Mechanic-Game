-- Catálogo de piezas que se compran en la tienda de la PC del taller.
--
-- El cliente solo lee esta tabla (ver ShopCatalog en scripts/shop_catalog.gd
-- para los íconos, que viven en el cliente y no acá). Los precios se pueden
-- ajustar desde este mismo editor sin tocar el juego.
--
-- Ejecutar en el SQL Editor de Supabase.

create table if not exists public.shop_items (
	key    text primary key,
	name   text not null,
	price  integer not null check (price >= 0),
	active boolean not null default true
);

alter table public.shop_items enable row level security;

create policy "shop_items_select_all"
	on public.shop_items for select
	to authenticated
	using (true);

insert into public.shop_items (key, name, price) values
	('oils', 'Aceite de motor', 20),
	('filters', 'Filtro de aire', 15),
	('lights', 'Bombillos', 25),
	('keys', 'Cerradura', 30)
on conflict (key) do nothing;
