# ---- REGLAS DE LA COMPETENCIA ----
# Cuenta de referencia: $5,000 (drawdown tipo "Static": siempre sobre el
# balance inicial, no sobre el punto más alto alcanzado).
RULES = {
    "starting_balance": 5000,
    "profit_target_pct": 10,       # 10% ($600) para calificar
    "max_daily_drawdown_pct": 3,   # 3% ($180) máximo de caída en un solo día
    "max_total_drawdown_pct": 6,   # 6% ($360) máximo de caída, sobre balance inicial (static)
    "min_trading_days": 2,         # días distintos operando, mínimo
    "max_lot_size": None,          # sin límite de lote especificado
    "news_trading_allowed": True,  # operar en noticias está permitido
    "performance_reward_pct": 15,  # % de la ganancia que se paga como reward ($90 de referencia)
    "competition_days": 30,        # duración total de la competencia
    "reset_applicable": False,     # no hay reset: quien incumple queda descalificado
}

# Ranking: entre quienes califican (check_qualified == True), se ordenan
# de mayor a menor gain_pct. min_trading_days=2 ya evita que alguien pase
# el reto en un solo día.


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

    if RULES["max_lot_size"] is not None and snapshot["max_lot_used"] > RULES["max_lot_size"]:
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
