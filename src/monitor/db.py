"""Conexão com o PostgreSQL do monitor."""

import psycopg

from monitor.config import carregar_config_banco


def conectar() -> psycopg.Connection:
    """Abre uma conexão com a database monitor_mkt.

    Uso:
        with conectar() as conn:
            conn.execute("SELECT 1")
    """
    cfg = carregar_config_banco()
    return psycopg.connect(
        host=cfg.host,
        port=cfg.porta,
        dbname=cfg.nome,
        user=cfg.usuario,
        password=cfg.senha,
        application_name="monitor_concorrentes",
    )
