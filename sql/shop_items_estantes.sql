-- Convierte "filters" y "keys" de pieza suelta a estante-decoracion, mismo
-- patron que "estante_aceite" (ver shop_items_decoracion.sql): se compran
-- una vez, se plantan en la sala, y tocandolos dan la pieza gratis (ver
-- "pieza_gratis" en scripts/room_object_catalog.gd). El nombre ya se habia
-- editado a mano en la base a "Estante de..."; esto termina de alinear el
-- tipo con ese nombre.
--
-- Ejecutar en el SQL Editor de Supabase (shop_items_decoracion.sql ya debe
-- haberse corrido antes).

update public.shop_items
set tipo = 'decoracion'
where key in ('filters', 'keys');
