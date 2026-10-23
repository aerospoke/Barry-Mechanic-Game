-- Economia del juego (ver scripts/economia.gd para los niveles y bonos).
--
--   Trabajos -> plata y puntos -> los puntos suben el nivel -> el nivel
--   desbloquea trabajos que pagan mas y articulos de la tienda.
--
-- Bonos al cobrar (calculados en el juego): primer trabajo del dia x2,
-- racha de dias seguidos (+5% por dia, hasta +50%) y experiencia (+4% por
-- cada nivel por encima del que pide el trabajo).
--
-- Niveles por puntos: 1 Aprendiz 0 · 2 Ayudante 15 · 3 Mecanico 40 ·
-- 4 Tecnico 80 · 5 Especialista 140 · 6 Jefe de taller 220 · 7 Maestro 320 ·
-- 8 Experto 450 · 9 Leyenda 620 · 10 Barry Supremo 850.
--
-- Este archivo se puede volver a correr: los numeros quedan como estan aca.
-- Ejecutar en el SQL Editor de Supabase.

-- 1) Columnas nuevas ---------------------------------------------------------

alter table public."WorkList" add column if not exists nivel_minimo integer not null default 1;
alter table public.shop_items add column if not exists nivel_minimo integer not null default 1;

alter table public.profiles add column if not exists racha_dias integer not null default 0;
alter table public.profiles add column if not exists ultimo_dia_trabajo date;

-- Los jugadores nuevos arrancan con $150: alcanza para el primer aceite y
-- algo de decoracion, pero no para un estante caro.
alter table public.profiles alter column balance set default 150;

-- 2) Trabajos: del mas facil al mas dificil ------------------------------------

update public."WorkList" w set payment = v.pago, points = v.puntos, nivel_minimo = v.nivel
from (values
	('inflate_tires',     35, 2, 1),
	('change_oil',        40, 2, 1),
	('change_air_filter', 55, 3, 2),
	('organize_tools',    60, 3, 3),
	('key_fix',           70, 4, 3),
	('electric_fix',      90, 5, 4),
	('paint_job',        120, 6, 5)
) as v(key, pago, puntos, nivel)
where w.key = v.key;

-- 3) Tienda -------------------------------------------------------------------
-- Repuestos baratos (se gastan en cada trabajo) y estantes caros que dan la
-- pieza gratis para siempre: invertir en un estante se paga solo despues de
-- varios trabajos. La decoracion "de lujo" pide nivel (Gold no).

update public.shop_items s set price = v.precio, nivel_minimo = v.nivel
from (values
	-- Repuestos
	('oils',              15, 1),
	('lights',            15, 1),
	-- Estantes (piezas gratis)
	('estante_aceite',   120, 1),
	('air',              140, 1),
	('filters',          150, 2),
	('tools',            180, 3),
	('keys',             180, 3),
	('cables',           220, 4),
	('paint',            250, 5),
	-- Especiales
	('radio',              0, 1),
	('ventana',           30, 1),
	('guacal',            60, 2),
	('radio_pro',        800, 4),
	('bandera',           60, 2),
	-- Muebles
	('sofa_rojo',        120, 2),
	('sofa_azul',        120, 2),
	('sillon_cuero',      90, 2),
	('nevera',           150, 2),
	('maquina_snacks',   180, 3),
	('arcade',           250, 5),
	('caja_registradora', 90, 2),
	-- Luces
	('poste_luz',        120, 3),
	('neon_rayo',        150, 4),
	-- Taller
	('motor_soporte',    200, 4),
	('caja_herramientas',110, 2),
	-- Trofeos: se ganan subiendo de nivel
	('trofeo_bronce',    100, 3),
	('placa_mes',        150, 4),
	('trofeo_plata',     180, 5),
	('vitrina_medallas', 220, 6),
	('trofeo_oro',       300, 7),
	('copa_campeon',     500, 9),
	-- Plantas
	('planta_bonsai',    120, 4),
	('planta_ficus',      80, 2),
	('planta_palmera',    70, 2)
) as v(key, precio, nivel)
where s.key = v.key;
