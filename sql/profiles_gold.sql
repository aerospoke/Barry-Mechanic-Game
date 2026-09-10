-- Marca si el jugador compro la membresia Gold (ver Supabase.buy_gold_
-- membership en supabase.gd y el panel de detalles en searchwork_ui.gd).
-- Pago unico: no hay fecha de vencimiento ni tabla de suscripcion, solo un
-- flag.
--
-- Ejecutar en el SQL Editor de Supabase.

alter table public.profiles add column if not exists is_gold boolean not null default false;
