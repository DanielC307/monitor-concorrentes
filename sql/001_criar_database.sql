-- =====================================================================
-- 001 - Cria os usuários e a database do Monitor de Concorrentes
-- Rodar UMA vez, como superusuário (ex.: postgres), conectado à
-- database "postgres":
--   psql -U postgres -h localhost -d postgres -f sql\001_criar_database.sql
--
-- ANTES DE RODAR: troque as duas senhas abaixo. Não faça commit das
-- senhas reais; elas vão só no arquivo .env de cada máquina.
-- =====================================================================

-- Usuário da aplicação: dono da database, usado pelos scripts Python.
CREATE ROLE monitor_app LOGIN PASSWORD 'TROCAR_SENHA_APP';

-- Usuário somente leitura: usado pelo Power BI (enxerga só o schema ouro).
CREATE ROLE monitor_leitura LOGIN PASSWORD 'TROCAR_SENHA_LEITURA';

-- No Windows, UTF8 funciona com qualquer locale.
CREATE DATABASE monitor_mkt
  OWNER monitor_app
  ENCODING 'UTF8'
  TEMPLATE template0;

-- Ninguém além desses dois usuários conecta na database do monitor.
REVOKE CONNECT ON DATABASE monitor_mkt FROM PUBLIC;
GRANT CONNECT ON DATABASE monitor_mkt TO monitor_app, monitor_leitura;
