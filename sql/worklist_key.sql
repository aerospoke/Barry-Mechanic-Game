-- Separa el nombre visible del trabajo (lo que ve el jugador en la lista y
-- en el boton de Barry) de su codigo interno (lo que usa el cliente para
-- saber que minijuego abrir, ver MINIGAMES en scripts/movement_script.gd).
-- Mismo patron que shop_items: "key" para matchear, "name" para mostrar.
--
-- Antes de correr esto, WorkList.name tenia los codigos (change_oil,
-- change_air_filter, electric_fix, key_fix) puestos a mano; este script los
-- mueve a la columna nueva "key" y devuelve "name" a texto legible.
--
-- Ejecutar en el SQL Editor de Supabase.

alter table public."WorkList" add column if not exists key text;

-- Copia lo que hoy esta en "name" (los codigos) a la columna nueva, solo si
-- todavia no se corrio esta migracion.
update public."WorkList" set key = name where key is null;

alter table public."WorkList" alter column key set not null;

create unique index if not exists worklist_key_uidx on public."WorkList" (key);

-- Devuelve "name" a texto para mostrar. Si agregas un trabajo nuevo despues,
-- alcanza con sumar su fila aca (o a mano en el editor).
update public."WorkList" set name = 'Cambio de aceite' where key = 'change_oil';
update public."WorkList" set name = 'Cambio de filtro de aire' where key = 'change_air_filter';
update public."WorkList" set name = 'Reparacion electrica' where key = 'electric_fix';
update public."WorkList" set name = 'Abrir puerta' where key = 'key_fix';
