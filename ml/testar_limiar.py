"""
testar_limiar.py
================
Mostra como precisao e recall mudam conforme o limiar de decisao.

Uso:
  python ml/testar_limiar.py
  python ml/testar_limiar.py --entrada ml/data/smart_telemetria.csv.gz --modelo ml/modelo
"""

import argparse
import os
import sys

import joblib
import pandas as pd
from sklearn.model_selection import GroupShuffleSplit

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from treinar_modelo import preparar, FEATURES


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--entrada", default="ml/data/backblaze_preparado.csv.gz")
    p.add_argument("--modelo", default="ml/modelo_backblaze")
    p.add_argument("--horizonte", type=int, default=30)
    a = p.parse_args()

    print("lendo dados...")
    df = preparar(pd.read_csv(a.entrada), a.horizonte)

    X, y, grupos = df[FEATURES], df["alvo"], df["serial_number"]
    _, i_teste = next(GroupShuffleSplit(n_splits=1, test_size=0.25,
                                        random_state=42).split(X, y, grupos))

    pacote = joblib.load(os.path.join(a.modelo, "modelo_falha_30d.joblib"))
    prob = pacote["modelo"].predict_proba(X.iloc[i_teste])[:, 1]
    y_te = y.iloc[i_teste]

    n_pos = int(y_te.sum())
    print(f"\nconjunto de teste: {len(y_te):,} linhas | {n_pos:,} positivos "
          f"({y_te.mean()*100:.2f}%)\n")

    print(f"{'limiar':>7} {'precisao':>9} {'recall':>8} {'F1':>7} "
          f"{'alertas':>9} {'acertos':>8}")
    print("-" * 52)

    for limiar in [0.30, 0.50, 0.60, 0.70, 0.80, 0.90, 0.95, 0.98]:
        pred = prob >= limiar
        tp = int((pred & (y_te == 1)).sum())
        fp = int((pred & (y_te == 0)).sum())
        fn = int((~pred & (y_te == 1)).sum())

        prec = tp / (tp + fp) if (tp + fp) else 0.0
        rec = tp / (tp + fn) if (tp + fn) else 0.0
        f1 = 2 * prec * rec / (prec + rec) if (prec + rec) else 0.0

        print(f"{limiar:>7.2f} {prec:>9.3f} {rec:>8.3f} {f1:>7.3f} "
              f"{tp+fp:>9,} {tp:>8,}")

    print("\nLeitura das colunas:")
    print("  precisao = de cada alerta emitido, quantos eram falha real")
    print("  recall   = das falhas reais, quantas o sistema pegou")
    print("  alertas  = quantos discos o tecnico teria que conferir")


if __name__ == "__main__":
    main()