"""
preparar_backblaze.py
=====================
Converte os CSVs diarios do Backblaze Drive Stats num arquivo unico, do mesmo
formato que ml/data/smart_telemetria.csv.gz, pronto para treinar_modelo.py e
para o notebook.

POR QUE ESTE SCRIPT EXISTE
--------------------------
Um trimestre do Backblaze tem ~345 mil discos x ~90 dias = ~31 MILHOES de
linhas, 12 GB em disco. Carregar tudo de uma vez com pd.concat estoura a
memoria de um PC comum. Alem disso, so ~0,3% dos discos falham no trimestre:
a esmagadora maioria dos dados e de discos saudaveis, que se repetem.

Solucao em duas passadas:
  1a passada - le so as colunas date/serial_number/failure e anota quais
               discos falharam no trimestre.
  2a passada - guarda TODOS os discos que falharam (sao o dado valioso e raro)
               mais uma amostra aleatoria dos saudaveis.

Resultado: arquivo de tamanho gerenciavel preservando 100% dos exemplos
positivos. Isso NAO e trapaca: reduzir a classe majoritaria por amostragem e
pratica padrao em classes desbalanceadas. O que seria errado e descartar
positivos, e isso nao acontece aqui.

COMO USAR
---------
1. Baixe um trimestre em:
   https://www.backblaze.com/cloud-storage/resources/hard-drive-test-data
   (Q1 2026 = 1,3 GB zipado, 12 GB descompactado, 91 arquivos)

2. Descompacte dentro de ml/data/backblaze/
   Deve ficar: ml/data/backblaze/2026-01-01.csv, 2026-01-02.csv, ...

3. Rode:
   python ml/preparar_backblaze.py
   python ml/preparar_backblaze.py --saudaveis 40000   (mais dados)
   python ml/preparar_backblaze.py --so-mecanicos      (exclui SSD)

4. Treine:
   python ml/treinar_modelo.py --entrada ml/data/backblaze_2026Q1.csv.gz

CITACAO OBRIGATORIA NO RELATORIO
--------------------------------
A Backblaze libera os dados de graca sob tres condicoes: citar a Backblaze
como fonte, assumir responsabilidade pelo uso, e nao revender os dados.
Citacao sugerida:

  Backblaze, Inc. Hard Drive Test Data. Disponivel em:
  https://www.backblaze.com/cloud-storage/resources/hard-drive-test-data
"""

import argparse
import glob
import os
import sys

import numpy as np
import pandas as pd

AQUI = os.path.dirname(os.path.abspath(__file__))

# Colunas que o nosso pipeline usa. O Backblaze publica mais de 200 colunas
# (raw e normalized de dezenas de atributos); pegamos so estas.
COLUNAS_BASE = ["date", "serial_number", "model", "capacity_bytes", "failure"]

COLUNAS_SMART = ["smart_5_raw", "smart_9_raw", "smart_12_raw",
                 "smart_187_raw", "smart_188_raw", "smart_194_raw",
                 "smart_197_raw", "smart_198_raw", "smart_199_raw",
                 "smart_241_raw"]

COLUNAS = COLUNAS_BASE + COLUNAS_SMART

# Tipos enxutos: int64 em 31 milhoes de linhas desperdicia gigabytes.
TIPOS = {"failure": "int8", "capacity_bytes": "int64"}


def _achar_arquivos(pasta):
    arquivos = sorted(glob.glob(os.path.join(pasta, "*.csv")))
    if not arquivos:
        # o zip as vezes cria uma subpasta com o nome do trimestre
        arquivos = sorted(glob.glob(os.path.join(pasta, "*", "*.csv")))
    return arquivos


def _ler(arquivo, colunas):
    """Le um CSV diario pegando so as colunas pedidas que existirem nele."""
    # O esquema muda entre trimestres: alguns atributos SMART aparecem ou
    # somem. usecols com funcao ignora silenciosamente o que nao existe.
    return pd.read_csv(arquivo, usecols=lambda c: c in colunas,
                       dtype=TIPOS, low_memory=False)


def primeira_passada(arquivos):
    """Descobre quais discos falharam durante o trimestre."""
    print("\n[1/3] Procurando discos que falharam...")
    falhados = set()
    todos = set()

    for i, arq in enumerate(arquivos, 1):
        d = _ler(arq, {"serial_number", "failure"})
        todos.update(d["serial_number"].unique())
        falhados.update(d.loc[d["failure"] == 1, "serial_number"].unique())
        if i % 15 == 0 or i == len(arquivos):
            print(f"      {i}/{len(arquivos)} arquivos | "
                  f"{len(todos):,} discos | {len(falhados):,} falhas")

    return todos, falhados


def segunda_passada(arquivos, manter):
    """Le de novo, guardando apenas os discos selecionados."""
    print("\n[2/3] Extraindo a telemetria dos discos selecionados...")
    partes = []

    for i, arq in enumerate(arquivos, 1):
        d = _ler(arq, set(COLUNAS))
        d = d[d["serial_number"].isin(manter)]
        if len(d):
            partes.append(d)
        if i % 15 == 0 or i == len(arquivos):
            linhas = sum(len(p) for p in partes)
            print(f"      {i}/{len(arquivos)} arquivos | {linhas:,} linhas")

    return pd.concat(partes, ignore_index=True)


def limpar(df):
    """Ajustes necessarios antes de treinar."""
    print("\n[3/3] Limpando...")

    # Garante que toda coluna SMART esperada existe, mesmo que o trimestre
    # nao a publique. O modelo espera todas.
    ausentes = [c for c in COLUNAS_SMART if c not in df.columns]
    for c in ausentes:
        df[c] = 0
    if ausentes:
        print(f"      atributos ausentes no trimestre, preenchidos com 0: "
              f"{', '.join(ausentes)}")

    # SMART vazio = atributo nao reportado por aquele modelo de disco.
    # Zero e a leitura correta: 'nenhum evento contado'.
    nulos = int(df[COLUNAS_SMART].isna().sum().sum())
    df[COLUNAS_SMART] = df[COLUNAS_SMART].fillna(0)
    print(f"      {nulos:,} valores SMART ausentes preenchidos com 0")

    # capacity_bytes = -1 significa que o disco nao respondeu a consulta.
    # Corrige pelo valor mais comum daquele modelo.
    ruins = (df["capacity_bytes"] <= 0).sum()
    if ruins:
        moda = (df[df["capacity_bytes"] > 0]
                .groupby("model")["capacity_bytes"]
                .agg(lambda s: s.mode().iloc[0] if len(s.mode()) else 0))
        mask = df["capacity_bytes"] <= 0
        df.loc[mask, "capacity_bytes"] = (df.loc[mask, "model"].map(moda)
                                          .fillna(0).astype("int64"))
        print(f"      {ruins:,} capacidades invalidas corrigidas pela moda "
              f"do modelo")

    # Contadores SMART sao cumulativos e nao-negativos. Valor negativo e
    # erro de leitura do proprio disco.
    for c in COLUNAS_SMART:
        neg = (df[c] < 0).sum()
        if neg:
            df.loc[df[c] < 0, c] = 0
            print(f"      {neg:,} valores negativos em {c} zerados")

    # Reduz o tamanho em memoria e no arquivo final
    for c in COLUNAS_SMART:
        df[c] = pd.to_numeric(df[c], downcast="integer", errors="coerce").fillna(0)

    return df.sort_values(["serial_number", "date"]).reset_index(drop=True)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--pasta", default=os.path.join(AQUI, "data", "backblaze"),
                   help="pasta com os CSVs diarios descompactados")
    p.add_argument("--saida", default=None,
                   help="arquivo .csv.gz de saida")
    p.add_argument("--saudaveis", type=int, default=25000,
                   help="quantos discos saudaveis amostrar (padrao 25000)")
    p.add_argument("--so-mecanicos", action="store_true",
                   help="descarta SSD; o parque escolar e quase todo HDD")
    p.add_argument("--seed", type=int, default=42)
    a = p.parse_args()

    arquivos = _achar_arquivos(a.pasta)
    if not arquivos:
        sys.exit(
            f"Nenhum CSV encontrado em {a.pasta}\n\n"
            "Baixe um trimestre em:\n"
            "  https://www.backblaze.com/cloud-storage/resources/"
            "hard-drive-test-data\n"
            f"e descompacte dentro de {a.pasta}")

    print("=" * 62)
    print(f"  {len(arquivos)} arquivos diarios encontrados")
    print(f"  de {os.path.basename(arquivos[0])} "
          f"a {os.path.basename(arquivos[-1])}")
    print("=" * 62)

    todos, falhados = primeira_passada(arquivos)

    rng = np.random.default_rng(a.seed)
    saudaveis = np.array(sorted(todos - falhados))
    n = min(a.saudaveis, len(saudaveis))
    amostra = set(rng.choice(saudaveis, n, replace=False))
    manter = falhados | amostra

    print(f"\n      discos no trimestre : {len(todos):,}")
    print(f"      falharam            : {len(falhados):,} "
          f"({len(falhados)/len(todos)*100:.3f}%)  -> TODOS mantidos")
    print(f"      saudaveis amostrados: {n:,} de {len(saudaveis):,}")
    print(f"      total a extrair     : {len(manter):,} discos")

    df = segunda_passada(arquivos, manter)
    df = limpar(df)

    if a.so_mecanicos:
        antes = df["serial_number"].nunique()
        padrao_ssd = r"SSD|Micron|Crucial|CT[0-9]+|MTFD|Seagate SSD|WDC WDS"
        df = df[~df["model"].str.contains(padrao_ssd, case=False, regex=True,
                                          na=False)]
        print(f"\n      SSDs removidos: "
              f"{antes - df['serial_number'].nunique():,} discos")

    saida = a.saida or os.path.join(AQUI, "data", "backblaze_preparado.csv.gz")
    df.to_csv(saida, index=False, compression="gzip")

    n_discos = df["serial_number"].nunique()
    n_falhas = int(df["failure"].sum())
    tam = os.path.getsize(saida) / 1e6

    print("\n" + "=" * 62)
    print(f"  linhas      : {len(df):,}")
    print(f"  discos      : {n_discos:,}")
    print(f"  falhas      : {n_falhas:,} ({n_falhas/n_discos*100:.2f}% dos discos)")
    print(f"  modelos     : {df['model'].nunique():,}")
    print(f"  periodo     : {df['date'].min()} a {df['date'].max()}")
    print(f"  arquivo     : {saida} ({tam:.1f} MB)")
    print("=" * 62)
    print("\nProximo passo:")
    print(f"  python ml/treinar_modelo.py --entrada {saida}")
    print("\nNao esqueca de citar a Backblaze como fonte no relatorio.")


if __name__ == "__main__":
    main()
