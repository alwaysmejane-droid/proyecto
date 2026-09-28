-- Tabla de participantes
-- login/server: público (identifican la cuenta). investor_password: de solo
-- lectura (no puede operar ni retirar) pero aun así se trata como dato
-- sensible: nunca se expone en el dashboard ni en logs.
create table if not exists participants (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  mt5_login text not null unique,
  mt5_investor_password text not null,
  mt5_server text not null,
  starting_balance numeric not null,
  created_at timestamptz default now()
);

-- Snapshot de cada lectura del robot (una fila por participante por corrida)
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
