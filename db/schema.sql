-- Tabla de participantes
-- report_token: secreto único por participante, generado al registrarlo.
-- Va dentro del EA que corre en su propia PC/VPS — nunca la clave de
-- Supabase. Si se filtra, solo permite reportar datos falsos de ESA
-- cuenta, nunca acceso a la base completa.
create table if not exists participants (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  mt5_login text not null unique,
  mt5_server text not null,
  report_token text not null unique default encode(gen_random_bytes(16), 'hex'),
  starting_balance numeric not null,
  created_at timestamptz default now()
);

-- Snapshot de cada reporte que manda el EA (una fila por envío)
create table if not exists account_snapshots (
  id uuid primary key default gen_random_uuid(),
  participant_id uuid references participants(id),
  balance numeric not null,
  equity numeric not null,
  drawdown_pct numeric not null,
  daily_drawdown_pct numeric not null,
  trades_count integer not null,
  max_lot_used numeric not null,
  trading_days integer not null,
  gain_pct numeric not null,
  fetched_at timestamptz default now()
);

-- Estado actual de cada participante (lo que lee el dashboard)
create table if not exists participant_status (
  participant_id uuid primary key references participants(id),
  status text not null default 'active', -- 'active' | 'disqualified' | 'qualified'
  disqualified_reason text,
  disqualified_at timestamptz,
  last_snapshot_id uuid references account_snapshots(id),
  updated_at timestamptz default now()
);
