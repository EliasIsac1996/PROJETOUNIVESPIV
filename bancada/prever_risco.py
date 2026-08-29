"""
prever_risco.py
===============
Usa o modelo treinado para calcular o risco de falha de UM disco lido na bancada.
E este arquivo que o script da bancada vai importar.

Uso como biblioteca:
    from prever_risco import calcular_risco
    r = calcular_risco(leitura_atual, leitura_anterior)
    print(r["risco"], r["faixa"])

Uso como demo pela linha de comando:
    python prever_risco.py

IMPORTANTE sobre as features d7_*: elas medem a VARIACAO do contador nos ultimos
7 dias. Na primeira vez que uma maquina passa pela bancada nao existe historico,
entao entram como 0 e o modelo julga so pelo valor absoluto. A partir da segunda
leitura (buscar a anterior no Firestore) a predicao fica bem melhor. Isso e um
argumento forte a favor da bancada: quanto mais a maquina passa, melhor o modelo.
"""

import os
import joblib
import pandas as pd

_DIR = os.path.dirname(os.path.abspath(__file__))
_RAIZ = os.path.dirname(_DIR)

# Procura o modelo em ml/modelo/ (padrao do repositorio) e, se nao achar,
# em bancada/modelo/ (util para copiar so a pasta bancada para o PC da escola).
_CANDIDATOS = [
    os.path.join(_RAIZ, "ml", "modelo", "modelo_falha_30d.joblib"),
    os.path.join(_DIR, "modelo", "modelo_falha_30d.joblib"),
]
CAMINHO_MODELO = next((c for c in _CANDIDATOS if os.path.exists(c)),
                      _CANDIDATOS[0])

CONTADORES = ["smart_5_raw", "smart_187_raw", "smart_188_raw",
              "smart_197_raw", "smart_198_raw", "smart_199_raw"]

_cache = None


def _carregar():
    global _cache
    if _cache is None:
        _cache = joblib.load(CAMINHO_MODELO)
    return _cache


def faixa_de(risco):
    """Traduz probabilidade em status visual para o LED e para o app Flutter."""
    if risco >= 0.60:
        return "CRITICO", "vermelho"
    if risco >= 0.25:
        return "ATENCAO", "amarelo"
    return "OK", "verde"


def calcular_risco(leitura, leitura_anterior=None, dias_entre=7):
    """
    leitura          : dict com os campos SMART lidos por smartctl + modelo/capacidade
    leitura_anterior : dict da leitura passada da MESMA maquina (opcional)
    dias_entre       : dias entre as duas leituras, para normalizar o delta em 7 dias
    """
    pacote = _carregar()
    modelo, features = pacote["modelo"], pacote["features"]

    l = dict(leitura)
    l["capacidade_gb"] = l["capacity_bytes"] / 1e9
    l["eh_ssd"] = int(any(t in l.get("model", "") for t in ("Kingston", "WDS", "SSD")))
    l["anos_ligado"] = l["smart_9_raw"] / (24 * 365)
    l["setores_ruins_total"] = (l["smart_5_raw"] + l["smart_197_raw"]
                                + l["smart_198_raw"])

    for c in CONTADORES:
        if leitura_anterior and dias_entre > 0:
            delta = max(0, l[c] - leitura_anterior.get(c, l[c]))
            l[f"d7_{c}"] = delta * (7.0 / dias_entre)  # normaliza para janela de 7d
        else:
            l[f"d7_{c}"] = 0.0

    X = pd.DataFrame([[l[f] for f in features]], columns=features)
    risco = float(modelo.predict_proba(X)[0, 1])
    status, cor = faixa_de(risco)

    return {
        "risco": round(risco, 4),
        "risco_pct": round(risco * 100, 1),
        "faixa": status,
        "cor_led": cor,
        "horizonte_dias": pacote["horizonte_dias"],
        "tinha_historico": leitura_anterior is not None,
    }


if __name__ == "__main__":
    saudavel = {
        "model": "HGST HTS541010", "capacity_bytes": 1_000_204_886_016,
        "smart_5_raw": 0, "smart_9_raw": 11000, "smart_12_raw": 1400,
        "smart_187_raw": 0, "smart_188_raw": 0, "smart_194_raw": 33,
        "smart_197_raw": 0, "smart_198_raw": 0, "smart_199_raw": 0,
    }
    doente = {
        "model": "ST500LM012 HN", "capacity_bytes": 500_107_862_016,
        "smart_5_raw": 412, "smart_9_raw": 39000, "smart_12_raw": 5200,
        "smart_187_raw": 96, "smart_188_raw": 21, "smart_194_raw": 46,
        "smart_197_raw": 188, "smart_198_raw": 74, "smart_199_raw": 3,
    }
    doente_antes = dict(doente, smart_5_raw=150, smart_187_raw=20,
                        smart_197_raw=40, smart_198_raw=12)

    print("disco saudavel        ->", calcular_risco(saudavel))
    print("disco ruim (sem hist) ->", calcular_risco(doente))
    print("disco ruim (com hist) ->", calcular_risco(doente, doente_antes, dias_entre=14))
