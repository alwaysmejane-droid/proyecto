create or replace view leaderboard as
select
  p.id,
  p.name,
  p.mt5_login,
  p.starting_balance,
  s.balance,
  s.equity,
  s.gain_pct,
  s.drawdown_pct,
  s.trades_count,
  s.trading_days,
  s.fetched_at,
  coalesce(ps.status, 'active') as status,
  ps.disqualified_reason
from participants p
left join lateral (
  select * from account_snapshots
  where participant_id = p.id
  order by fetched_at desc
  limit 1
) s on true
left join participant_status ps on ps.participant_id = p.id
order by s.gain_pct desc nulls last;
