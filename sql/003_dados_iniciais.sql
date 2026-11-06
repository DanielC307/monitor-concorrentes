-- =====================================================================
-- 003 - Dados iniciais: concorrentes e linhas de produto
-- Rodar como monitor_app, conectado à database monitor_mkt:
--   psql -U monitor_app -h localhost -d monitor_mkt -f sql\003_dados_iniciais.sql
-- Os perfis (páginas e contas de cada concorrente) são cadastrados na
-- Fase 0, depois de levantados um a um.
-- =====================================================================

BEGIN;

INSERT INTO prata.concorrentes (nome) VALUES
  ('EcoAutomação'),
  ('Advantech Brasil'),
  ('SDC'),
  ('Datasonic'),
  ('Hoscorp Tecnologia'),
  ('Rockwell Automation'),
  ('Siemens'),
  ('Beckhoff Automation Brasil');

INSERT INTO prata.linhas_produto (nome, ordem) VALUES
  ('PCs industriais',       1),
  ('IHM e monitores',       2),
  ('Sistemas de I/O',       3),
  ('Switches e firewalls',  4),
  ('IoT e conversores',     5),
  ('Robôs colaborativos',   6),
  ('Outros',                99);

COMMIT;
