"""Configuração lida do arquivo .env (nunca de valores fixos no código)."""

import os
from dataclasses import dataclass

from dotenv import load_dotenv


@dataclass(frozen=True)
class ConfigBanco:
    host: str
    porta: int
    nome: str
    usuario: str
    senha: str


def carregar_config_banco() -> ConfigBanco:
    """Lê as variáveis DB_* do ambiente ou do .env na raiz do projeto."""
    load_dotenv()
    faltando = [v for v in ("DB_HOST", "DB_NAME", "DB_USER", "DB_PASSWORD") if not os.getenv(v)]
    if faltando:
        raise RuntimeError(
            f"Variáveis ausentes no .env: {', '.join(faltando)}. "
            "Copie .env.example para .env e preencha."
        )
    return ConfigBanco(
        host=os.environ["DB_HOST"],
        porta=int(os.getenv("DB_PORT", "5432")),
        nome=os.environ["DB_NAME"],
        usuario=os.environ["DB_USER"],
        senha=os.environ["DB_PASSWORD"],
    )
