# Monitor de Concorrentes

**Acompanhe o marketing da concorrência sem precisar entrar página por página.**

O Monitor de Concorrentes visita todos os dias as bibliotecas públicas de anúncios, os sites e os canais dos concorrentes, guarda tudo o que eles publicam e anunciam, e organiza esse material num dashboard. Em vez de abrir a Meta Ad Library e o LinkedIn de cada empresa toda semana, você abre um painel e vê o que mudou.

> Ferramenta interna da Portwell Automation, em desenvolvimento. Veja o que já funciona em [Status](#status).

## O que dá para descobrir

- **Quem está anunciando agora**, e se é na Meta (Facebook e Instagram) ou no Google.
- **Quais anúncios estão no ar há mais tempo.** Anúncio que roda por meses sem ser trocado costuma ser anúncio que dá resultado, e é uma ótima referência para as nossas campanhas.
- **Que produtos cada concorrente está empurrando**, separados pelas nossas linhas: PCs industriais, IHMs e monitores, sistemas de I/O, switches e firewalls, IoT e conversores, robôs colaborativos.
- **Que formatos e mensagens eles usam:** vídeo, carrossel, case; chamadas para orçamento, demonstração, material ou evento.
- **Com que frequência publicam**, e quando o ritmo muda (por exemplo, perto de uma feira).
- **Em quais regiões aparecem**, quando a fonte informa.
- **Para quais páginas mandam o tráfego** dos anúncios.

## Como funciona

1. **Coleta.** Todo dia, a ferramenta consulta as fontes públicas de cada concorrente cadastrado e guarda a resposta exatamente como veio.
2. **Organização.** Cada anúncio ou post vira um registro único. A cada dia ela anota se o anúncio continua no ar, e é assim que sabe há quanto tempo ele está rodando.
3. **Classificação.** Uma IA lê cada peça e marca a linha de produto, o segmento, o formato e o objetivo.
4. **Dashboard.** O Power BI lê os dados prontos e mostra tudo em painéis.

Como o histórico fica guardado, dá para ver anúncios que já saíram do ar, coisa que as próprias bibliotecas de anúncios não mostram.

## Status

| Recurso | Situação |
| --- | --- |
| Banco de dados, cadastro de concorrentes e linhas de produto | Disponível |
| Consultas prontas para análise (views) | Disponível |
| Coleta de sites e blogs | Em desenvolvimento |
| Coleta de YouTube, Meta Ad Library e Google Ads | Planejado |
| Classificação por IA | Planejado |
| Dashboard no Power BI com atualização automática | Planejado |

## Instalação

Você vai precisar de:

- Windows com **WSL (Ubuntu)**, ou Linux
- **Python 3.12**
- Cliente do PostgreSQL: `sudo apt install postgresql-client`
- Acesso à rede da empresa e um usuário do banco `monitor_mkt` (peça ao responsável pelo projeto)

```bash
git clone git@github.com:SEU_USUARIO/monitor-concorrentes.git
cd monitor-concorrentes
python3.12 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
pip install -e .
cp .env.example .env
```

Abra o `.env` e preencha o endereço do servidor e a sua senha:

```
DB_HOST=192.168.0.199
DB_PASSWORD=sua_senha
```

Confira se está tudo certo:

```bash
python -m monitor.testar_conexao
```

O resultado deve mostrar a conexão, os schemas `bronze`, `prata` e `ouro`, os concorrentes e as linhas de produto cadastrados.

> Montando o banco do zero num servidor novo? Siga o [docs/setup.md](docs/setup.md).

## Como usar

### Ver os concorrentes cadastrados

Conecte no banco pelo `psql`, pelo pgAdmin ou por uma extensão do VS Code, e rode:

```sql
SELECT id, nome, ativo FROM prata.concorrentes ORDER BY nome;
```

### Adicionar um concorrente

```sql
INSERT INTO prata.concorrentes (nome, site) VALUES ('Nome da Empresa', 'https://www.empresa.com.br');
```

Para parar de acompanhar um concorrente, desative em vez de apagar, para não perder o histórico:

```sql
UPDATE prata.concorrentes SET ativo = false WHERE nome = 'Nome da Empresa';
```

### Cadastrar as páginas e contas de um concorrente

A ferramenta só coleta o que estiver cadastrado como **perfil**. Cada concorrente pode ter vários: o site, a página na Meta, o anunciante no Google, a página no LinkedIn, o canal no YouTube. Para multinacionais, cadastre só as páginas brasileiras.

```sql
INSERT INTO prata.perfis (concorrente_id, fonte, identificador, url)
VALUES (1, 'site', 'empresa.com.br', 'https://www.empresa.com.br');
```

O campo `fonte` aceita `site`, `youtube`, `meta_ads`, `google_ads` e `linkedin`. O `identificador` muda conforme a fonte:

| Fonte | Identificador | Onde encontrar |
| --- | --- | --- |
| `site` | Domínio | Endereço do site, sem `https://` |
| `youtube` | ID do canal | Página do canal → Sobre → Compartilhar canal → Copiar ID |
| `meta_ads` | ID da página | Na Meta Ad Library, no endereço da página do anunciante |
| `google_ads` | ID do anunciante | No Google Ads Transparency Center, no endereço do anunciante (começa com `AR`) |
| `linkedin` | Nome da página | O final do endereço: `linkedin.com/company/`**`nome-da-pagina`** |

### Consultar os dados

As consultas prontas ficam no schema `ouro` e são as mesmas que alimentam o dashboard:

```sql
-- Resumo de cada concorrente nas últimas 12 semanas
SELECT * FROM ouro.vw_resumo_concorrente ORDER BY pecas_12s DESC;

-- Anúncios no ar agora, dos mais antigos para os mais novos
SELECT concorrente, fonte, titulo, dias_ativos
FROM ouro.vw_anuncios_ativos
ORDER BY dias_ativos DESC;

-- Publicações por semana de um concorrente
SELECT semana, pecas FROM ouro.vw_semanal
WHERE concorrente = 'Siemens' ORDER BY semana;

-- A coleta está funcionando? Última execução de cada fonte
SELECT * FROM ouro.vw_saude_coleta;
```

### Conectar o Power BI

No Power BI Desktop, em **Obter dados → Banco de dados PostgreSQL**:

- **Servidor:** `192.168.0.199`
- **Banco de dados:** `monitor_mkt`
- **Usuário:** `monitor_leitura` (somente leitura; peça a senha ao responsável)

Selecione as views do schema `ouro`. Para o relatório publicado atualizar sozinho, o On-premises Data Gateway precisa estar configurado no servidor.

## Limitações

- **Gasto e alcance dos anúncios não aparecem.** No Brasil, a Meta e o Google não divulgam quanto cada anunciante investe nem quantas pessoas viram cada anúncio.
- **A região é parcial.** O Google informa onde os anúncios rodam; a Meta não. Para o resto, a região é deduzida de cidades e eventos citados no texto.
- **LinkedIn tem coleta limitada.** Os termos de uso proíbem coleta automática, então essa fonte depende de registro manual ou de serviços de terceiros.
- **Só dados públicos de empresas.** A ferramenta não coleta comentários nem informações de pessoas.

## Para quem vai desenvolver

O [CLAUDE.md](CLAUDE.md) reúne todo o contexto do projeto: decisões, arquitetura, taxonomia, fases e regras. Ele é lido automaticamente pelo Claude Code, mas também é o melhor ponto de partida para uma pessoa.

- [docs/schema.md](docs/schema.md): tabelas e relações do banco, com diagrama.
- [docs/setup.md](docs/setup.md): como montar o ambiente e o banco do zero.

Rode os testes com `pytest`. Mudanças no banco entram como um novo script numerado em `sql/`; scripts que já rodaram no servidor nunca são editados.

---

Projeto interno da Portwell Automation. Uso restrito.
