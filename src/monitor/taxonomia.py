"""Valores fechados da classificação (fonte única da verdade).

O banco só restringe as linhas de produto (tabela prata.linhas_produto).
As demais dimensões são validadas aqui, antes de gravar.
"""

from typing import Literal

Fonte = Literal["meta_ads", "google_ads", "linkedin", "youtube", "site"]
TipoPeca = Literal["anuncio", "post"]

LinhaProduto = Literal[
    "PCs industriais",
    "IHM e monitores",
    "Sistemas de I/O",
    "Switches e firewalls",
    "IoT e conversores",
    "Robôs colaborativos",
    "Outros",
]
Segmento = Literal[
    "Alimentos e bebidas", "Metalmecânico", "Automotivo", "Químico", "Saneamento", "Outros",
]
Formato = Literal["Vídeo", "Carrossel", "Imagem única", "Texto", "Case", "Evento ou webinar"]
Objetivo = Literal[
    "Pedir orçamento", "Agendar demo", "Baixar material", "Inscrição em evento", "Institucional",
]
Tom = Literal["Técnico", "Comercial", "Institucional"]

UFS = (
    "AC", "AL", "AP", "AM", "BA", "CE", "DF", "ES", "GO", "MA", "MT", "MS", "MG", "PA",
    "PB", "PR", "PE", "PI", "RJ", "RN", "RS", "RO", "RR", "SC", "SP", "SE", "TO",
)
