# ---- REGLAS DE LA COMPETENCIA (ajustar con los números reales) ----
RULES = {
    "profit_target_pct": 10,       # % de ganancia para calificar
    "max_daily_drawdown_pct": 5,   # % máximo de caída en un solo día
    "max_total_drawdown_pct": 10,  # % máximo de caída desde el inicio
    "min_trading_days": 5,         # días distintos operando, mínimo
    "max_lot_size": 1.0,           # tamaño máximo de posición
    "competition_days": 30,        # duración total en días
}


def check_violations(snapshot: dict) -> list[str]:
    """Recibe un snapshot de una cuenta y devuelve la lista de reglas violadas."""
    violations = []

    if snapshot["daily_drawdown_pct"] > RULES["max_daily_drawdown_pct"]:
        violations.append(
            f"Drawdown diario {snapshot['daily_drawdown_pct']}% > "
            f"límite {RULES['max_daily_drawdown_pct']}%"
        )

    if snapshot["drawdown_pct"] > RULES["max_total_drawdown_pct"]:
        violations.append(
            f"Drawdown total {snapshot['drawdown_pct']}% > "
            f"límite {RULES['max_total_drawdown_pct']}%"
        )

    if snapshot["max_lot_used"] > RULES["max_lot_size"]:
        violations.append(
            f"Lote {snapshot['max_lot_used']} > "
            f"límite {RULES['max_lot_size']}"
        )

    return violations


def check_qualified(snapshot: dict) -> bool:
    """True si la cuenta ya cumplió el objetivo para ganar."""
    return (
        snapshot["gain_pct"] >= RULES["profit_target_pct"]
        and snapshot["trading_days"] >= RULES["min_trading_days"]
    )
