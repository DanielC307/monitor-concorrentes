# Preparação do ambiente (Windows)

Passo a passo para deixar o projeto rodando, do zero até o teste de conexão. Os comandos são para o PowerShell, a partir da pasta do projeto.

## 1. Ferramentas

| Ferramenta | Para quê | Observação |
| --- | --- | --- |
| Python 3.12 | Código do projeto | Em python.org; marque "Add python.exe to PATH" na instalação |
| Git | Versionamento | Em git-scm.com |
| VS Code + Claude Code | Desenvolvimento | Já instalados |
| Extensão Python (Microsoft) | Rodar e depurar o código | No marketplace do VS Code |
| Extensão Markdown Preview Mermaid Support | Ver o diagrama em `docs/schema.md` | `bierner.markdown-mermaid` |
| psql ou pgAdmin | Rodar os scripts SQL | Já vêm com o PostgreSQL do servidor |

Confira no terminal:

```powershell
py --version
git --version
```

## 2. Repositório

Coloque esta pasta onde for trabalhar e inicie o Git:

```powershell
git init
git add .
git commit -m "Estrutura inicial do monitor de concorrentes"
```

Se a empresa usa GitHub ou Azure DevOps, crie um repositório **privado** e envie para lá. O `.gitignore` já impede que o `.env` (com senhas) vá junto.

## 3. Ambiente Python

```powershell
py -3.12 -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
pip install -e .
```

Se o PowerShell bloquear o `Activate.ps1`, rode uma vez `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`.

No VS Code, `Ctrl+Shift+P` → "Python: Select Interpreter" → escolha o `.venv` da pasta.

## 4. Banco de dados

**De onde você vai conectar.** Se desenvolver no seu próprio PC, o PostgreSQL do servidor precisa aceitar conexões da sua máquina pela rede (arquivo `pg_hba.conf` e `listen_addresses`). Como o PRM provavelmente já faz isso, pergunte ao time do PRM como eles conectam. Nos comandos abaixo, troque `localhost` pelo nome ou IP do servidor quando rodar de outra máquina.

**4.1 — Usuários e database** (uma vez, como superusuário). Antes, abra `sql/001_criar_database.sql` e troque as duas senhas `TROCAR_SENHA_...`; guarde-as num cofre de senhas, não no Git.

```powershell
psql -U postgres -h localhost -d postgres -f sql\001_criar_database.sql
```

**4.2 — Schema e dados iniciais** (como `monitor_app`):

```powershell
psql -U monitor_app -h localhost -d monitor_mkt -f sql\002_schema.sql
psql -U monitor_app -h localhost -d monitor_mkt -f sql\003_dados_iniciais.sql
```

Depois de rodar o 001, volte as senhas do arquivo para `TROCAR_SENHA_...` antes de qualquer commit.

## 5. Arquivo `.env`

```powershell
Copy-Item .env.example .env
```

Abra o `.env` e preencha `DB_HOST` e `DB_PASSWORD` (a senha do `monitor_app`).

## 6. Teste final

```powershell
python -m monitor.testar_conexao
pytest
```

O resultado esperado é algo como:

```
Conectado ao PostgreSQL 16.x
Schemas bronze, prata e ouro: ok
Concorrentes cadastrados: 8
Linhas de produto cadastradas: 7
```

Com isso o ambiente está pronto para a Fase 1.

## Pendente fora do código

- **Backup do PostgreSQL**: não existe hoje; precisa estar ativo antes da Fase 1 começar a guardar histórico (ver documento de planejamento).
- **Gateway do Power BI**: instalar o On-premises Data Gateway no mini servidor quando o dashboard real for montado, conectando com o usuário `monitor_leitura`.
