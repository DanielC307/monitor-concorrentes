"""Confere se o ambiente está pronto: python -m monitor.testar_conexao"""

from monitor.db import conectar


def main() -> None:
    with conectar() as conn:
        versao = conn.execute("SHOW server_version").fetchone()[0]
        print(f"Conectado ao PostgreSQL {versao}")

        schemas = {
            r[0]
            for r in conn.execute(
                "SELECT nspname FROM pg_namespace WHERE nspname IN ('bronze', 'prata', 'ouro')"
            )
        }
        faltando = {"bronze", "prata", "ouro"} - schemas
        if faltando:
            print(f"Schemas ausentes: {', '.join(sorted(faltando))}. Rode sql/002_schema.sql.")
            return

        n_conc = conn.execute("SELECT count(*) FROM prata.concorrentes").fetchone()[0]
        n_linhas = conn.execute("SELECT count(*) FROM prata.linhas_produto").fetchone()[0]
        print(f"Schemas bronze, prata e ouro: ok")
        print(f"Concorrentes cadastrados: {n_conc}")
        print(f"Linhas de produto cadastradas: {n_linhas}")
        if n_conc == 0:
            print("Nenhum concorrente: rode sql/003_dados_iniciais.sql.")


if __name__ == "__main__":
    main()
