from typing import get_args

from monitor.taxonomia import UFS, LinhaProduto


def test_linhas_produto_batem_com_o_banco():
    # Deve bater com sql/003_dados_iniciais.sql
    assert set(get_args(LinhaProduto)) == {
        "PCs industriais", "IHM e monitores", "Sistemas de I/O", "Switches e firewalls",
        "IoT e conversores", "Robôs colaborativos", "Outros",
    }


def test_27_ufs():
    assert len(UFS) == 27 and len(set(UFS)) == 27
