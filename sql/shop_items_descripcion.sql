-- Descripcion de cada articulo de la tienda: se muestra debajo de la imagen
-- grande del carrusel (ver _mostrar_articulo en scripts/searchwork_ui.gd).
-- Si un articulo no tiene descripcion, la tienda muestra un texto generico
-- segun su tipo (pieza o decoracion).
--
-- Ejecutar en el SQL Editor de Supabase.

alter table public.shop_items add column if not exists description text;

update public.shop_items set description = d.description
from (values
	('oils', 'Aceite de motor para los cambios de aceite. Barry lo lleva en la mano hasta el carro.'),
	('filters', 'Estante de filtros de aire. Tocalo con las manos vacias y Barry saca un filtro nuevo, gratis, cuantas veces quieras.'),
	('lights', 'Bombillos para los faros del carro.'),
	('keys', 'Estante de cerrajeria con ganzuas para abrir puertas de carros. Saca las herramientas gratis cuando quieras.'),
	('estante_aceite', 'Estante lleno de aceite de motor. Ponlo en tu taller y saca aceite gratis para cada cambio.'),
	('cables', 'Estante de corriente con cables y multimetro: para las reparaciones electricas. ¡Guia la corriente por el circuito!'),
	('tools', 'Banco de herramientas para tu taller. Con el puedes aceptar trabajos de ordenar herramientas como un rompecabezas.'),
	('air', 'Compresor de aire para inflar llantas. ¡Cuidado de no pasarte de presion!'),
	('paint', 'Estante de pinturas y sprays para retocar los rayones de los carros.')
) as d(key, description)
where shop_items.key = d.key;
