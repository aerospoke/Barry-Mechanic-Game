-- Traje (overol de color) que lleva Barry. Los trajes y como se
-- desbloquean viven en scripts/vestuario.gd; aca solo se guarda cual eligio.
--
-- Ejecutar en el SQL Editor de Supabase.

alter table public.profiles add column if not exists outfit text not null default 'clasico';
