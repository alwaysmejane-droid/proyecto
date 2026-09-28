-- Participantes fantasma para previsualizar el dashboard con datos reales.
-- Bórralos luego con: delete from participants where name like 'Fantasma%';

do $$
declare
  p_id uuid;
begin
  -- 1: líder, calificado
  insert into participants (name, mt5_login, mt5_server, starting_balance)
  values ('Fantasma Carlos', '90000001', 'Demo', 5000) returning id into p_id;
  insert into account_snapshots (participant_id, balance, equity, drawdown_pct, daily_drawdown_pct, trades_count, max_lot_used, trading_days, gain_pct)
  values (p_id, 5680, 5650, 0.8, 0.3, 34, 0.5, 6, 13.6);
  insert into participant_status (participant_id, status)
  values (p_id, 'qualified');

  -- 2: activo, ganando
  insert into participants (name, mt5_login, mt5_server, starting_balance)
  values ('Fantasma Maria', '90000002', 'Demo', 5000) returning id into p_id;
  insert into account_snapshots (participant_id, balance, equity, drawdown_pct, daily_drawdown_pct, trades_count, max_lot_used, trading_days, gain_pct)
  values (p_id, 5220, 5200, 1.2, 0.5, 21, 0.3, 4, 4.4);
  insert into participant_status (participant_id, status)
  values (p_id, 'active');

  -- 3: activo, apenas positivo
  insert into participants (name, mt5_login, mt5_server, starting_balance)
  values ('Fantasma Luis', '90000003', 'Demo', 5000) returning id into p_id;
  insert into account_snapshots (participant_id, balance, equity, drawdown_pct, daily_drawdown_pct, trades_count, max_lot_used, trading_days, gain_pct)
  values (p_id, 5040, 5010, 0.9, 0.4, 12, 0.2, 3, 0.8);
  insert into participant_status (participant_id, status)
  values (p_id, 'active');

  -- 4: descalificado por drawdown total
  insert into participants (name, mt5_login, mt5_server, starting_balance)
  values ('Fantasma Pedro', '90000004', 'Demo', 5000) returning id into p_id;
  insert into account_snapshots (participant_id, balance, equity, drawdown_pct, daily_drawdown_pct, trades_count, max_lot_used, trading_days, gain_pct)
  values (p_id, 4600, 4550, 9, 4, 40, 1.2, 5, -8);
  insert into participant_status (participant_id, status, disqualified_reason)
  values (p_id, 'disqualified', 'Drawdown total 9% > 6%');

  -- 5: descalificado por drawdown diario
  insert into participants (name, mt5_login, mt5_server, starting_balance)
  values ('Fantasma Ana', '90000005', 'Demo', 5000) returning id into p_id;
  insert into account_snapshots (participant_id, balance, equity, drawdown_pct, daily_drawdown_pct, trades_count, max_lot_used, trading_days, gain_pct)
  values (p_id, 4750, 4700, 5, 5.5, 18, 0.8, 2, -5);
  insert into participant_status (participant_id, status, disqualified_reason)
  values (p_id, 'disqualified', 'Drawdown diario 5.5% > 3%');

  -- 6: activo, ligeramente en pérdida
  insert into participants (name, mt5_login, mt5_server, starting_balance)
  values ('Fantasma Sofia', '90000006', 'Demo', 5000) returning id into p_id;
  insert into account_snapshots (participant_id, balance, equity, drawdown_pct, daily_drawdown_pct, trades_count, max_lot_used, trading_days, gain_pct)
  values (p_id, 4900, 4880, 2.4, 1, 8, 0.4, 2, -2);
  insert into participant_status (participant_id, status)
  values (p_id, 'active');
end $$;
