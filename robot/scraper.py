"""
Robot de la competencia (login directo a MT5):
1. Lee la lista de participantes desde Supabase (login, investor password, servidor).
2. Para cada uno: conecta al terminal MT5, entra con su contraseña de
   inversor (solo lectura), saca los datos, se desconecta.
3. Revisa las reglas (rules.py).
4. Guarda el snapshot y el estado (activo/descalificado/calificado) en Supabase.

Requiere Windows + terminal MetaTrader 5 instalado (ver .github/workflows/robot.yml).

Variables de entorno necesarias (Secrets en GitHub):
- SUPABASE_URL
- SUPABASE_KEY
"""

import os
import time
import MetaTrader5 as mt5
from supabase import create_client
from rules import check_violations, check_qualified

supabase = create_client(os.environ["SUPABASE_URL"], os.environ["SUPABASE_KEY"])


MT5_PATH = os.environ.get("MT5_PATH")  # ruta a terminal64.exe, localizada por el workflow


def fetch_account_data(login: str, investor_password: str, server: str) -> dict:
    """Se conecta a una cuenta en modo solo-lectura y saca sus datos."""
    kwargs = {"timeout": 60000}
    if MT5_PATH:
        kwargs["path"] = MT5_PATH
    initialized = mt5.initialize(**kwargs)
    if not initialized:
        raise RuntimeError(f"No se pudo iniciar MT5: {mt5.last_error()}")

    authorized = mt5.login(
        int(login), password=investor_password, server=server, timeout=60000
    )
    if not authorized:
        mt5.shutdown()
        raise RuntimeError(f"Login falló para {login}: {mt5.last_error()}")

    info = mt5.account_info()
    deals = mt5.history_deals_get(0, int(time.time()))
    deals = deals or []

    trading_days = len({d.time // 86400 for d in deals if d.entry == 1})
    lots = [d.volume for d in deals if d.volume]
    max_lot_used = max(lots) if lots else 0

    data = {
        "balance": info.balance,
        "equity": info.equity,
        "trades_count": len([d for d in deals if d.entry == 1]),
        "max_lot_used": max_lot_used,
        "trading_days": trading_days,
        # drawdown_pct / daily_drawdown_pct: requieren el historial de equity
        # a lo largo del día/competencia; se calculan en process_snapshot()
        # a partir de starting_balance por ahora (placeholder simple).
    }

    mt5.shutdown()
    return data


def run():
    participants = supabase.table("participants").select("*").execute().data

    for p in participants:
        try:
            data = fetch_account_data(
                p["mt5_login"], p["mt5_investor_password"], p["mt5_server"]
            )
        except Exception as e:
            print(f"[ERROR] {p['name']}: {e}")
            continue

        starting = p["starting_balance"]
        gain_pct = round((data["balance"] - starting) / starting * 100, 2)
        drawdown_pct = round(max(0, (starting - data["equity"]) / starting * 100), 2)

        snapshot = {
            **data,
            "participant_id": p["id"],
            "gain_pct": gain_pct,
            "drawdown_pct": drawdown_pct,
            "daily_drawdown_pct": drawdown_pct,  # placeholder: ver nota abajo
        }

        saved = supabase.table("account_snapshots").insert(snapshot).execute().data[0]

        violations = check_violations(snapshot)
        qualified = check_qualified(snapshot)

        if violations:
            status, reason = "disqualified", "; ".join(violations)
        elif qualified:
            status, reason = "qualified", None
        else:
            status, reason = "active", None

        supabase.table("participant_status").upsert({
            "participant_id": p["id"],
            "status": status,
            "disqualified_reason": reason,
            "last_snapshot_id": saved["id"],
        }).execute()

        print(f"{p['name']}: {status} (ganancia {gain_pct}%)")


if __name__ == "__main__":
    run()

# NOTA sobre daily_drawdown_pct: para calcularlo bien (caída dentro de un
# solo día, no acumulada) hace falta guardar el equity más alto del día en
# curso y compararlo en cada corrida. Por ahora usa el mismo valor que el
# drawdown total como placeholder — lo afinamos cuando probemos con datos
# reales.
