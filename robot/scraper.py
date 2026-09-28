"""
Robot de la competencia:
1. Lee la lista de participantes desde Supabase.
2. Para cada uno, entra a su página pública de Signal en MQL5 y saca los datos.
3. Revisa las reglas (rules.py).
4. Guarda el snapshot y el estado (activo/descalificado) en Supabase.

Variables de entorno necesarias (se configuran como "Secrets" en GitHub):
- SUPABASE_URL
- SUPABASE_KEY
"""

import os
import requests
from bs4 import BeautifulSoup
from supabase import create_client
from rules import check_violations, check_qualified

supabase = create_client(os.environ["SUPABASE_URL"], os.environ["SUPABASE_KEY"])


def fetch_signal_data(signal_url: str) -> dict:
    """Descarga y parsea la página pública de un Signal de MQL5."""
    resp = requests.get(signal_url, timeout=15, headers={"User-Agent": "Mozilla/5.0"})
    resp.raise_for_status()
    soup = BeautifulSoup(resp.text, "html.parser")

    # NOTA: estos selectores hay que ajustarlos mirando el HTML real
    # de una página de Signal antes de usarlo en producción.
    def get_stat(label: str) -> str:
        el = soup.find(string=label)
        return el.find_next("span").text.strip() if el else "0"

    return {
        "balance": float(get_stat("Balance").replace(",", "")),
        "equity": float(get_stat("Equity").replace(",", "")),
        "drawdown_pct": float(get_stat("Drawdown").replace("%", "")),
        "daily_drawdown_pct": float(get_stat("Drawdown diario").replace("%", "")),
        "trades_count": int(get_stat("Trades") or 0),
        "max_lot_used": float(get_stat("Lote máximo") or 0),
        "trading_days": int(get_stat("Días operando") or 0),
    }


def run():
    participants = supabase.table("participants").select("*").execute().data

    for p in participants:
        try:
            data = fetch_signal_data(p["mql5_signal_url"])
        except Exception as e:
            print(f"[ERROR] {p['name']}: no se pudo leer el signal ({e})")
            continue

        gain_pct = round(
            (data["balance"] - p["starting_balance"]) / p["starting_balance"] * 100, 2
        )
        snapshot = {**data, "participant_id": p["id"], "gain_pct": gain_pct}

        saved = supabase.table("account_snapshots").insert(snapshot).execute().data[0]

        violations = check_violations(snapshot)
        qualified = check_qualified(snapshot)

        if violations:
            status = "disqualified"
            reason = "; ".join(violations)
        elif qualified:
            status = "qualified"
            reason = None
        else:
            status = "active"
            reason = None

        supabase.table("participant_status").upsert({
            "participant_id": p["id"],
            "status": status,
            "disqualified_reason": reason,
            "last_snapshot_id": saved["id"],
        }).execute()

        print(f"{p['name']}: {status} (ganancia {gain_pct}%)")


if __name__ == "__main__":
    run()
