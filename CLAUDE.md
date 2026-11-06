# Monitor de Concorrentes — Portwell Automation

Ferramenta interna que coleta todo dia o que os concorrentes da Portwell Automation publicam e anunciam, classifica esse material com IA e alimenta um dashboard no Power BI. O objetivo é usar o marketing dos concorrentes como referência para o tráfego pago da Portwell (temas, formatos, palavras-chave, regiões).

Responda sempre em português do Brasil.

## Sobre quem desenvolve

O desenvolvedor tem noções de engenharia de dados, mas é o primeiro projeto desse tipo. Por isso:

- Explique o porquê de cada decisão técnica em uma ou duas frases, sem aula longa.
- Trabalhe em passos pequenos e testáveis; mostre como rodar e conferir cada passo.
- Antes de instalar pacotes, criar tabelas ou mudar a estrutura de pastas, diga o que vai fazer e por quê.
- Quando houver mais de um caminho razoável, apresente as opções com o trade-off e recomende uma.

## Estado atual

- **Planejamento:** concluído. O documento completo está no Claude (Monitor de Marketing de Concorrentes — Planejamento).
- **Protótipo visual do dashboard:** aprovado, com dados fictícios. Cinco páginas: Visão geral, Anúncios, Conteúdo, Ritmo e Regiões.
- **Ambiente:** banco e esqueleto Python prontos (ver `docs/setup.md`).
- **Próximo:** Fase 0 (coleta manual para validar) e Fase 1 (coleta automatizada) em paralelo, porque o projeto tem pressa.

## Concorrentes monitorados

EcoAutomação, Advantech Brasil, SDC, Datasonic, Hoscorp Tecnologia, Rockwell Automation, Siemens e Beckhoff Automation Brasil.

Rockwell, Siemens, Beckhoff e Advantech são multinacionais com muitas páginas e contas pelo mundo. Colete só as páginas brasileiras e os anúncios veiculados no Brasil; cada conta é um registro em `prata.perfis`.

## Perguntas que o dashboard responde

Todo dado coletado precisa servir a pelo menos uma destas perguntas. Se não serve, não entra.

1. Quem está anunciando agora, e em quais canais?
2. Quais anúncios estão rodando há mais tempo? (anúncio longevo tende a ser anúncio que funciona)
3. Quais produtos e segmentos cada concorrente mais promove?
4. Quais formatos predominam?
5. Que mensagens e chamadas usam (orçamento, demo, material, evento)?
6. Em quais regiões aparecem? (dado parcial, ver limitações)
7. Com que frequência publicam, e o ritmo mudou?
8. Para quais páginas mandam o tráfego?

## Fontes de dados e limitações

| Fonte | Como coletar | Limitação |
| --- | --- | --- |
| Meta Ad Library | Scraper de terceiros (Apify) sobre o site público | A API oficial só cobre anúncios comerciais na UE/Reino Unido; no Brasil não há gasto, impressões nem região |
| Google Ads Transparency Center | Manual na Fase 0; depois ferramenta de terceiros | Acesso programático limitado; é a fonte com região |
| Sites e blogs | `sitemap.xml` e RSS | Cada site tem estrutura própria |
| YouTube | YouTube Data API (oficial) | Cota diária |
| LinkedIn | Manual ou serviço de terceiros | Termos de uso proíbem scraping |

**Fora do escopo:** gasto e impressões de anúncios (não são públicos no Brasil), comentários e perfis de pessoas, alertas em tempo real, TikTok/Kwai/X/Pinterest. SEMrush e Similarweb foram descartados: a ferramenta é própria.

Região, quando a fonte não informa, é inferida de cidades, estados e eventos citados no texto ou na landing page.

## Arquitetura

- **Onde roda:** mini servidor Windows da empresa, ligado 24 horas.
- **Banco:** PostgreSQL já existente no servidor (compartilhado com os projetos PRM e Almoxarifado), na database própria `monitor_mkt`.
- **Agendamento:** Agendador de Tarefas do Windows, uma vez por dia.
- **Dashboard:** Power BI (já licenciado), lendo o schema `ouro` com o usuário `monitor_leitura`, via On-premises Data Gateway instalado no servidor.
- **Camadas:** `bronze` (resposta bruta, nunca alterada) → `prata` (limpo, sem duplicatas, snapshots, classificação) → `ouro` (views para o dashboard).

O schema completo, com diagrama, está em `docs/schema.md`. O SQL em `sql/` é a fonte da verdade.

## Classificação com IA

Um modelo de linguagem lê o texto e os metadados de cada peça e devolve JSON com valores fechados. As listas ficam em `src/monitor/taxonomia.py` (fonte única da verdade; só as linhas de produto também estão no banco):

- **Linha de produto:** PCs industriais, IHM e monitores, Sistemas de I/O, Switches e firewalls, IoT e conversores, Robôs colaborativos, Outros
- **Segmento:** Alimentos e bebidas, Metalmecânico, Automotivo, Químico, Saneamento, Outros
- **Formato:** Vídeo, Carrossel, Imagem única, Texto, Case, Evento ou webinar
- **Objetivo:** Pedir orçamento, Agendar demo, Baixar material, Inscrição em evento, Institucional
- **Tom:** Técnico, Comercial, Institucional
- **Região mencionada:** UF ou nada

Validação: 50 peças classificadas à mão na Fase 0 formam o gabarito; a IA precisa concordar em 85% ou mais por campo. Peças com confiança baixa vão para revisão humana. Reclassificar cria uma linha nova em `prata.classificacoes` e marca a anterior como não vigente.

## Fases

| Fase | Entrega | Portão para seguir |
| --- | --- | --- |
| 0 · Descoberta | Perfis de cada concorrente levantados, coleta manual, gabarito de 50 peças, protótipo com dados reais | Time de marketing usou o protótipo |
| 1 · Coleta | Coletores (Meta, Google, sites, YouTube) gravando no bronze, processamento para o prata, agendamento diário | 7 dias de coleta sem falha |
| 2 · IA | Prompt, taxonomia, teste contra o gabarito, fila de revisão | 85% de acerto no gabarito |
| 3 · Dashboard | Views do ouro, Power BI com atualização automática, rotina semanal de uso, alerta de coleta vazia | — |

## Estrutura do projeto

```
CLAUDE.md                 este arquivo
docs/schema.md            schema do banco com diagrama
docs/setup.md             preparação do ambiente no Windows
sql/                      scripts numerados (001, 002...), rodados em ordem
src/monitor/config.py     leitura do .env
src/monitor/db.py         conexão com o banco
src/monitor/taxonomia.py  valores fechados da classificação
src/monitor/testar_conexao.py
tests/                    testes (pytest)
```

Pastas previstas, a criar quando a fase chegar: `src/monitor/coletores/` (um módulo por fonte), `src/monitor/processamento/` (bronze → prata), `src/monitor/classificacao/` e `tarefas/` (scripts `.ps1` para o Agendador de Tarefas).

## Comandos

```powershell
.venv\Scripts\Activate.ps1          # ativar o ambiente
python -m monitor.testar_conexao    # conferir banco e ambiente
pytest                              # rodar os testes
```

## Regras do projeto

- **Banco compartilhado:** nunca conecte, leia ou altere as databases do PRM ou do Almoxarifado. O projeto usa só a `monitor_mkt`, com o usuário `monitor_app`.
- **Mudanças no schema:** nunca edite um arquivo de `sql/` já rodado no servidor; crie o próximo número (`004_...sql`) e atualize `docs/schema.md` (inclusive o diagrama) no mesmo commit.
- **Bronze é intocável:** toda resposta de fonte é gravada em `bronze.respostas_brutas` antes de qualquer tratamento, e nunca é alterada depois.
- **Coleta idempotente:** rodar o mesmo coletor duas vezes no mesmo dia não pode duplicar nada (`INSERT ... ON CONFLICT` em `prata.pecas`; um snapshot por peça por dia).
- **Toda execução registrada:** cada coletor cria uma linha em `bronze.execucoes_coleta` e termina com `sucesso`, `vazia` ou `falha`, com a mensagem de erro.
- **Sem scraping próprio** de LinkedIn ou Instagram (termos de uso).
- **Sem dados pessoais:** só perfis de empresas; nada de comentários ou perfis de pessoas (LGPD).
- **Segredos só no `.env`:** senhas e chaves de API nunca no código nem no Git.
- **Código:** Python 3.12, nomes de tabelas, colunas, funções e variáveis em português sem acento, `snake_case`, type hints, funções pequenas, SQL com parâmetros (nunca montar SQL concatenando strings).

## Pendências fora do código

- **Backup:** o PostgreSQL do servidor não tem rotina de backup. Proposta (no planejamento): `pg_dump` diário da `monitor_mkt` em formato `-Fc`, cópia para fora do servidor, 7 diárias e 4 semanais, teste de restauração mensal. Precisa estar ativo antes de a Fase 1 guardar histórico real.
- **Usuário principal no marketing** e **orçamento mensal** de serviços (Apify, API de IA): ainda não definidos.
