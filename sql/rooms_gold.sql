-- Marca si la sala pertenece a una cuenta Gold (ver sql/profiles_gold.sql):
-- se guarda una copia en "rooms" en vez de leer profiles.is_gold del dueño
-- cada vez, porque un visitante de la sala no necesariamente puede leer el
-- perfil de otro jugador (RLS de profiles es mas restrictiva que la de
-- rooms, que ya se ve entre todos). El cliente lo usa para ocultar el
-- banner publicitario de la pared (ver room.gd _actualizar_banner_gold).
--
-- Se mantiene sincronizado en dos puntos del cliente (supabase.gd):
--   - create_room(): la sala nueva nace con el valor actual de profile_is_gold.
--   - buy_gold_membership(): al comprar, se actualizan de una todas las
--     salas que el jugador ya tenia.
--
-- Ejecutar en el SQL Editor de Supabase (profiles_gold.sql ya debe haberse
-- corrido antes).

alter table public.rooms add column if not exists owner_gold boolean not null default false;

-- Por si esto se corre despues de que alguien ya haya comprado la membresia:
-- sincroniza sus salas existentes de una.
update public.rooms r
set owner_gold = true
from public.profiles p
where p.id = r.owner and p.is_gold = true and r.owner_gold = false;
