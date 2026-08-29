"""
treinar_modelo.py
=================
Treina o classificador que prediz falha de disco nos proximos 30 dias.

Entrada : data/smart_telemetria.csv.gz  (schema Backblaze)
Saidas  : modelo/modelo_falha_30d.joblib
          modelo/metricas.json
          modelo/importancia_features.csv

Uso:
  python treinar_modelo.py
  python treinar_modelo.py --horizonte 30 --entrada data/smart_telemetria.csv.gz

Ponto critico do metodo: a separacao treino/teste e feita POR DISCO, nunca por
linha. Se o mesmo disco aparecer nos dois lados, o modelo "cola" e a metrica sobe
falsamente. Isso e o erro numero 1 em trabalho de manutencao preditiva.
"""

import argparse
import json
import os

import joblib
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import (average_precision_score, classification_report,
                             confusion_matrix, roc_auc_score)
from sklearn.model_selection import GroupShuffleSplit

CONTADORES = ["smart_5_raw", "smart_187_raw", "smart_188_raw",
              "smart_197_raw", "smart_198_raw", "smart_199_raw"]

FEATURES = [
    "smart_5_raw", "smart_9_raw", "smart_12_raw", "smart_187_raw",
    "smart_188_raw", "smart_194_raw", "smart_197_raw", "smart_198_raw",
    "smart_199_raw", "capacidade_gb", "eh_ssd", "anos_ligado",
    # variacao recente: a VELOCIDADE de degradacao vale mais que o valor absoluto
    "d7_smart_5_raw", "d7_smart_187_raw", "d7_smart_188_raw",
    "d7_smart_197_raw", "d7_smart_198_raw", "d7_smart_199_raw",
    "setores_ruins_total",
]


def preparar(df, horizonte=30):
    df = df.copy()
    df["date"] = pd.to_datetime(df["date"])
    df = df.sort_values(["serial_number", "date"]).reset_index(drop=True)

    # --- rotulo: esse disco falha nos proximos `horizonte` dias? ---
    falhou = df[df["failure"] == 1][["serial_number", "date"]]
    falhou = falhou.rename(columns={"date": "data_falha"})
    df = df.merge(falhou, on="serial_number", how="left")
    dias_ate = (df["data_falha"] - df["date"]).dt.days
    df["alvo"] = ((dias_ate >= 0) & (dias_ate <= horizonte)).astype(int)

    # --- features derivadas ---
    df["capacidade_gb"] = df["capacity_bytes"] / 1e9
    df["eh_ssd"] = df["model"].str.contains("Kingston|WDS|SSD", regex=True).astype(int)
    df["anos_ligado"] = df["smart_9_raw"] / (24 * 365)
    df["setores_ruins_total"] = (df["smart_5_raw"] + df["smart_197_raw"]
                                 + df["smart_198_raw"])

    g = df.groupby("serial_number")
    for c in CONTADORES:
        df[f"d7_{c}"] = (df[c] - g[c].shift(7)).fillna(0).clip(lower=0)

    return df


def main():
    aqui = os.path.dirname(os.path.abspath(__file__))

    p = argparse.ArgumentParser()
    p.add_argument("--entrada", default=None)
    p.add_argument("--horizonte", type=int, default=30)
    p.add_argument("--saida", default=None)
    a = p.parse_args()

    # caminhos relativos ao proprio script: funciona de qualquer pasta
    if a.entrada is None:
        a.entrada = os.path.join(aqui, "data", "smart_telemetria.csv.gz")
    if a.saida is None:
        a.saida = os.path.join(aqui, "modelo")

    if not os.path.exists(a.entrada):
        raise SystemExit(
            f"Arquivo nao encontrado: {a.entrada}\n"
            f"Gere os dados antes com: python ml/gerar_dataset.py")

    os.makedirs(a.saida, exist_ok=True)

    print("lendo dados...")
    df = pd.read_csv(a.entrada)
    print(f"  {len(df):,} linhas, {df['serial_number'].nunique():,} discos")

    print("preparando features e rotulo...")
    df = preparar(df, a.horizonte)
    print(f"  positivos: {int(df['alvo'].sum()):,} linhas "
          f"({df['alvo'].mean()*100:.2f}%)")

    X = df[FEATURES]
    y = df["alvo"]
    grupos = df["serial_number"]

    # separacao POR DISCO
    gss = GroupShuffleSplit(n_splits=1, test_size=0.25, random_state=42)
    i_tr, i_te = next(gss.split(X, y, grupos))
    X_tr, X_te, y_tr, y_te = X.iloc[i_tr], X.iloc[i_te], y.iloc[i_tr], y.iloc[i_te]
    print(f"  treino: {len(X_tr):,} linhas / {grupos.iloc[i_tr].nunique():,} discos")
    print(f"  teste : {len(X_te):,} linhas / {grupos.iloc[i_te].nunique():,} discos")

    print("treinando RandomForest...")
    modelo = RandomForestClassifier(
        n_estimators=300,
        max_depth=14,
        min_samples_leaf=8,
        class_weight="balanced_subsample",  # classe rara: obrigatorio
        n_jobs=-1,
        random_state=42,
    )
    modelo.fit(X_tr, y_tr)

    prob = modelo.predict_proba(X_te)[:, 1]
    pred = (prob >= 0.5).astype(int)

    auc = roc_auc_score(y_te, prob)
    ap = average_precision_score(y_te, prob)
    cm = confusion_matrix(y_te, pred)
    rel = classification_report(y_te, pred, target_names=["ok", "falha_30d"],
                                output_dict=True, zero_division=0)

    print("\n--- resultado no conjunto de teste ---")
    print(f"ROC AUC            : {auc:.4f}")
    print(f"PR AUC (avg prec.) : {ap:.4f}   <- metrica que importa em classe rara")
    print(f"matriz de confusao :\n{cm}")
    print(classification_report(y_te, pred, target_names=["ok", "falha_30d"],
                                zero_division=0))

    imp = (pd.DataFrame({"feature": FEATURES,
                         "importancia": modelo.feature_importances_})
           .sort_values("importancia", ascending=False))
    print("top 8 features:")
    print(imp.head(8).to_string(index=False))

    joblib.dump({"modelo": modelo, "features": FEATURES,
                 "horizonte_dias": a.horizonte}, 
                os.path.join(a.saida, "modelo_falha_30d.joblib"))
    imp.to_csv(os.path.join(a.saida, "importancia_features.csv"), index=False)
    with open(os.path.join(a.saida, "metricas.json"), "w") as f:
        json.dump({"roc_auc": auc, "pr_auc": ap,
                   "matriz_confusao": cm.tolist(),
                   "relatorio": rel,
                   "horizonte_dias": a.horizonte,
                   "n_treino": int(len(X_tr)), "n_teste": int(len(X_te))},
                  f, indent=2)
    print(f"\nmodelo salvo em {a.saida}/modelo_falha_30d.joblib")


if __name__ == "__main__":
    main()
