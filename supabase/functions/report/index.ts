// Recibe el reporte que manda el EA desde el MT5 de cada participante.
// Valida su report_token, aplica las reglas de la competencia, guarda el
// snapshot y actualiza el estado (activo / calificado / descalificado).
//
// Deploy: supabase functions deploy report
// URL resultante: https://<PROJECT_REF>.supabase.co/functions/v1/report

import { createClient } from "npm:@supabase/supabase-js@2";

const RULES = {
  profitTargetPct: 10,
  maxDailyDrawdownPct: 3,
  maxTotalDrawdownPct: 6,
  minTradingDays: 2,
};

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, // solo vive en el server, nunca en el EA
);

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const body = await req.json().catch(() => null);
  if (!body) return new Response("Invalid JSON", { status: 400 });

  const { login, token, balance, equity, trades_count, max_lot_used, trading_days, symbols_traded } = body;
  if (!login || !token) {
    return new Response("Missing login/token", { status: 400 });
  }

  const { data: participant, error: pErr } = await supabase
    .from("participants")
    .select("*")
    .eq("mt5_login", String(login))
    .eq("report_token", token)
    .single();

  if (pErr || !participant) {
    return new Response("Invalid login/token", { status: 401 });
  }

  const starting = Number(participant.starting_balance);
  const gain_pct = Math.round(((balance - starting) / starting) * 10000) / 100;
  const drawdown_pct = Math.round((Math.max(0, (starting - equity) / starting) * 10000)) / 100;

  const snapshot = {
    participant_id: participant.id,
    balance,
    equity,
    drawdown_pct,
    daily_drawdown_pct: drawdown_pct, // ver nota en robot/scraper.py sobre este placeholder
    trades_count,
    max_lot_used,
    trading_days,
    gain_pct,
    symbols_traded: symbols_traded || null,
  };

  const { data: saved, error: sErr } = await supabase
    .from("account_snapshots")
    .insert(snapshot)
    .select()
    .single();

  if (sErr) return new Response(`DB error: ${sErr.message}`, { status: 500 });

  const violations: string[] = [];
  if (drawdown_pct > RULES.maxDailyDrawdownPct) {
    violations.push(`Drawdown diario ${drawdown_pct}% > ${RULES.maxDailyDrawdownPct}%`);
  }
  if (drawdown_pct > RULES.maxTotalDrawdownPct) {
    violations.push(`Drawdown total ${drawdown_pct}% > ${RULES.maxTotalDrawdownPct}%`);
  }

  const qualified = gain_pct >= RULES.profitTargetPct && trading_days >= RULES.minTradingDays;

  const status = violations.length ? "disqualified" : qualified ? "qualified" : "active";

  await supabase.from("participant_status").upsert({
    participant_id: participant.id,
    status,
    disqualified_reason: violations.join("; ") || null,
    last_snapshot_id: saved.id,
    updated_at: new Date().toISOString(),
  });

  return new Response(JSON.stringify({ status, gain_pct }), {
    headers: { "Content-Type": "application/json" },
  });
});
