-- =====================================================================
-- 002 - Schemas, tabelas e views do Monitor de Concorrentes
-- Rodar como monitor_app, conectado à database monitor_mkt:
--   psql -U monitor_app -h localhost -d monitor_mkt -f sql\002_schema.sql
--
-- Camadas:
--   bronze: dado bruto de cada coleta, nunca alterado
--   prata:  dado limpo, sem duplicatas, com snapshots e classificação
--   ouro:   views prontas para o dashboard (Power BI lê só daqui)
-- =====================================================================

BEGIN;

CREATE SCHEMA bronze;
CREATE SCHEMA prata;
CREATE SCHEMA ouro;

-- ---------------------------------------------------------------------
-- PRATA: cadastros
-- ---------------------------------------------------------------------

-- Um concorrente monitorado.
CREATE TABLE prata.concorrentes (
  id          integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nome        text        NOT NULL UNIQUE,
  site        text,
  ativo       boolean     NOT NULL DEFAULT true,
  criado_em   timestamptz NOT NULL DEFAULT now()
);

-- Uma conta/página de um concorrente numa fonte. Multinacionais têm
-- várias (ex.: Siemens Brasil no LinkedIn, anunciante Siemens no Google).
-- identificador: id da página na Meta, id do anunciante no Google,
-- slug da página no LinkedIn, id do canal no YouTube ou domínio do site.
CREATE TABLE prata.perfis (
  id              integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  concorrente_id  integer     NOT NULL REFERENCES prata.concorrentes (id),
  fonte           text        NOT NULL
                  CHECK (fonte IN ('meta_ads', 'google_ads', 'linkedin', 'youtube', 'site')),
  identificador   text        NOT NULL,
  url             text,
  ativo           boolean     NOT NULL DEFAULT true,
  criado_em       timestamptz NOT NULL DEFAULT now(),
  UNIQUE (fonte, identificador)
);
CREATE INDEX perfis_concorrente_idx ON prata.perfis (concorrente_id);

-- Linhas de produto da taxonomia (dimensão central do dashboard).
CREATE TABLE prata.linhas_produto (
  id     smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nome   text     NOT NULL UNIQUE,
  ordem  smallint NOT NULL DEFAULT 0,
  ativa  boolean  NOT NULL DEFAULT true
);

-- ---------------------------------------------------------------------
-- BRONZE: dado bruto
-- ---------------------------------------------------------------------

-- Uma execução de um coletor (uma fonte, um horário).
CREATE TABLE bronze.execucoes_coleta (
  id               bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  fonte            text        NOT NULL
                   CHECK (fonte IN ('meta_ads', 'google_ads', 'linkedin', 'youtube', 'site')),
  iniciada_em      timestamptz NOT NULL DEFAULT now(),
  finalizada_em    timestamptz,
  status           text        NOT NULL DEFAULT 'rodando'
                   CHECK (status IN ('rodando', 'sucesso', 'vazia', 'falha')),
  itens_coletados  integer     NOT NULL DEFAULT 0,
  erro             text
);

-- A resposta original de uma fonte para um perfil, guardada como veio.
-- Permite reprocessar tudo sem coletar de novo.
CREATE TABLE bronze.respostas_brutas (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  execucao_id   bigint      NOT NULL REFERENCES bronze.execucoes_coleta (id),
  perfil_id     integer     NOT NULL REFERENCES prata.perfis (id),
  coletado_em   timestamptz NOT NULL DEFAULT now(),
  payload       jsonb       NOT NULL,
  hash_payload  text        NOT NULL
);
CREATE INDEX respostas_perfil_data_idx ON bronze.respostas_brutas (perfil_id, coletado_em);
CREATE INDEX respostas_execucao_idx ON bronze.respostas_brutas (execucao_id);

-- ---------------------------------------------------------------------
-- PRATA: peças, snapshots e classificações
-- ---------------------------------------------------------------------

-- Um anúncio ou post, único por perfil + id na fonte.
CREATE TABLE prata.pecas (
  id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  perfil_id           integer     NOT NULL REFERENCES prata.perfis (id),
  id_na_fonte         text        NOT NULL,
  tipo                text        NOT NULL CHECK (tipo IN ('anuncio', 'post')),
  titulo              text,
  texto               text,
  url_criativo        text,
  landing_page        text,
  url_original        text,
  data_inicio         date,
  data_fim            date,
  primeira_coleta     timestamptz NOT NULL DEFAULT now(),
  ultima_coleta       timestamptz NOT NULL DEFAULT now(),
  origem_resposta_id  bigint      REFERENCES bronze.respostas_brutas (id),
  UNIQUE (perfil_id, id_na_fonte),
  CHECK (data_fim IS NULL OR data_inicio IS NULL OR data_fim >= data_inicio)
);
CREATE INDEX pecas_data_inicio_idx ON prata.pecas (data_inicio);

-- Uma peça vista numa coleta: guarda se estava ativa e as métricas
-- públicas daquele dia. Chave composta: no máximo 1 snapshot por dia.
CREATE TABLE prata.snapshots (
  peca_id      bigint  NOT NULL REFERENCES prata.pecas (id) ON DELETE CASCADE,
  data_coleta  date    NOT NULL,
  ativa        boolean NOT NULL,
  metricas     jsonb   NOT NULL DEFAULT '{}'::jsonb,
  PRIMARY KEY (peca_id, data_coleta)
);

-- O resultado da IA para uma peça. Reclassificar cria uma linha nova e
-- marca a anterior como vigente = false (o índice garante só 1 vigente).
-- Os valores de segmento, formato, objetivo e tom são validados no
-- Python (src/monitor/taxonomia.py), não no banco.
CREATE TABLE prata.classificacoes (
  id                   bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  peca_id              bigint       NOT NULL REFERENCES prata.pecas (id) ON DELETE CASCADE,
  linha_produto_id     smallint     REFERENCES prata.linhas_produto (id),
  segmento             text,
  formato              text,
  objetivo             text,
  tom                  text,
  uf                   char(2),
  regiao_texto         text,
  confianca            numeric(3,2) CHECK (confianca BETWEEN 0 AND 1),
  modelo               text         NOT NULL,
  prompt_versao        text         NOT NULL,
  revisado_por_humano  boolean      NOT NULL DEFAULT false,
  vigente              boolean      NOT NULL DEFAULT true,
  classificado_em      timestamptz  NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX classificacoes_uma_vigente_idx
  ON prata.classificacoes (peca_id) WHERE vigente;
CREATE INDEX classificacoes_linha_idx ON prata.classificacoes (linha_produto_id);

-- ---------------------------------------------------------------------
-- OURO: views para o dashboard
-- ---------------------------------------------------------------------

-- Uma linha por peça, com concorrente, fonte, classificação vigente e
-- o estado do snapshot mais recente.
CREATE VIEW ouro.vw_pecas AS
SELECT
  p.id                AS peca_id,
  c.nome              AS concorrente,
  pf.fonte,
  p.tipo,
  p.titulo,
  p.landing_page,
  p.url_original,
  p.data_inicio,
  p.data_fim,
  lp.nome             AS linha_produto,
  cl.segmento,
  cl.formato,
  cl.objetivo,
  cl.tom,
  cl.uf,
  COALESCE(s.ativa, false) AS ativa,
  s.data_coleta       AS ultimo_snapshot,
  CASE WHEN p.tipo = 'anuncio' AND p.data_inicio IS NOT NULL
       THEN COALESCE(p.data_fim, s.data_coleta, CURRENT_DATE) - p.data_inicio + 1
  END                 AS dias_ativos
FROM prata.pecas p
JOIN prata.perfis pf       ON pf.id = p.perfil_id
JOIN prata.concorrentes c  ON c.id = pf.concorrente_id
LEFT JOIN prata.classificacoes cl ON cl.peca_id = p.id AND cl.vigente
LEFT JOIN prata.linhas_produto lp ON lp.id = cl.linha_produto_id
LEFT JOIN LATERAL (
  SELECT sn.ativa, sn.data_coleta
  FROM prata.snapshots sn
  WHERE sn.peca_id = p.id
  ORDER BY sn.data_coleta DESC
  LIMIT 1
) s ON true;

-- Resumo por concorrente nas últimas 12 semanas. Parte do cadastro para
-- que concorrentes sem nenhuma peça também apareçam (com zero).
CREATE VIEW ouro.vw_resumo_concorrente AS
SELECT
  c.nome AS concorrente,
  count(v.peca_id) FILTER (WHERE v.data_inicio >= CURRENT_DATE - 84)                      AS pecas_12s,
  count(v.peca_id) FILTER (WHERE v.tipo = 'post' AND v.data_inicio >= CURRENT_DATE - 84)  AS posts_12s,
  count(v.peca_id) FILTER (WHERE v.tipo = 'anuncio' AND v.ativa)                          AS anuncios_ativos,
  mode() WITHIN GROUP (ORDER BY v.fonte)         FILTER (WHERE v.data_inicio >= CURRENT_DATE - 84) AS canal_principal,
  mode() WITHIN GROUP (ORDER BY v.linha_produto) FILTER (WHERE v.data_inicio >= CURRENT_DATE - 84) AS linha_principal
FROM prata.concorrentes c
LEFT JOIN ouro.vw_pecas v ON v.concorrente = c.nome
WHERE c.ativo
GROUP BY c.nome;

-- Anúncios no ar agora, com há quanto tempo estão rodando.
CREATE VIEW ouro.vw_anuncios_ativos AS
SELECT peca_id, concorrente, fonte, titulo, objetivo, linha_produto, landing_page, data_inicio, dias_ativos
FROM ouro.vw_pecas
WHERE tipo = 'anuncio' AND ativa;

-- Peças publicadas por concorrente e semana (semana começa na segunda).
CREATE VIEW ouro.vw_semanal AS
SELECT
  concorrente,
  date_trunc('week', data_inicio)::date AS semana,
  count(*) AS pecas
FROM ouro.vw_pecas
WHERE data_inicio IS NOT NULL
GROUP BY concorrente, date_trunc('week', data_inicio);

-- Saúde da coleta: última execução de cada fonte.
CREATE VIEW ouro.vw_saude_coleta AS
SELECT DISTINCT ON (fonte)
  fonte, iniciada_em, finalizada_em, status, itens_coletados, erro
FROM bronze.execucoes_coleta
ORDER BY fonte, iniciada_em DESC;

-- ---------------------------------------------------------------------
-- Permissões do Power BI: só leitura, só no schema ouro.
-- (As views rodam com a permissão do dono, então o leitor não precisa
-- de acesso a bronze e prata.)
-- ---------------------------------------------------------------------
GRANT USAGE ON SCHEMA ouro TO monitor_leitura;
GRANT SELECT ON ALL TABLES IN SCHEMA ouro TO monitor_leitura;
ALTER DEFAULT PRIVILEGES IN SCHEMA ouro GRANT SELECT ON TABLES TO monitor_leitura;

COMMIT;
