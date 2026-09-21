"""
main.py
=======
Orquestrador da bancada. E o programa que o tecnico roda.

FLUXO COMPLETO:
  1. Conecta no Arduino (valida que a bancada fisica esta plugada)
  2. Le hardware da maquina (BIOS, CPU, RAM, disco + SMART)
  3. Busca a leitura anterior dessa maquina no Firestore (para as features d7_*)
  4. Calcula o risco de falha do disco com o modelo treinado
  5. Manda o Arduino acender o LED correspondente
  6. Envia o inventario para o Firestore
  7. Sincroniza qualquer pendencia offline

USO:
  python main.py                 # ciclo unico
  python main.py --loop          # fica esperando; ENTER dispara nova leitura
  python main.py --simular       # sem Arduino e sem Firebase (para desenvolver)
  python main.py --porta COM3    # forca a porta serial

PRECISA DE ADMINISTRADOR (Windows) ou sudo (Linux) para ler BIOS e SMART.
"""

import argparse
import json
import os
import sys
from datetime import datetime, timezone

import arduino
import firebase_client as fb
import leitor_hardware as hw
import prever_risco

DIR = os.path.dirname(os.path.abspath(__file__))
CONFIG = os.path.join(DIR, "config.json")

C_VERDE = "\033[92m"
C_AMAR = "\033[93m"
C_VERM = "\033[91m"
C_CINZA = "\033[90m"
C_OFF = "\033[0m"

COR_FAIXA = {"OK": C_VERDE, "ATENCAO": C_AMAR, "CRITICO": C_VERM,
             "QUARENTENA": C_VERM}

# Dicionario simples de escolas para validacao rapida
ESCOLAS_EXEMPLO = {
    "85397": "SERRA AZUL",
    "24296": "FRANCISCO FERREIRA DE FREITAS"
}


def carregar_config():
    padrao = {"id_bancada": "URE-01-BANCADA-01", "ure": "URE Exemplo",
              "porta_serial": None, "operador": "tecnico"}
    if os.path.exists(CONFIG):
        with open(CONFIG, encoding="utf-8") as f:
            padrao.update(json.load(f))
    return padrao


def cabecalho(cfg):
    print("=" * 66)
    print("  INVENTARIO - BANCADA DE VALIDACAO FISICA E PREDITIVA")
    print(f"  {cfg['id_bancada']}  |  {cfg['ure']}")
    print("=" * 66)


def solicitar_escola():
    """Pergunta o CIE ao tecnico e valida."""
    while True:
        print(f"\n{C_AMAR}ESCOLAS CONHECIDAS:{C_OFF}")
        for cie, nome in ESCOLAS_EXEMPLO.items():
            print(f"  {cie} - {nome}")

        cie = input(f"\nDigite o CIE da escola (ou ENTER para Pular): ").strip()
        if not cie:
            return None, "Nao Informada"

        if cie in ESCOLAS_EXEMPLO:
            nome = ESCOLAS_EXEMPLO[cie]
            print(f"{C_VERDE}Escola selecionada: {nome}{C_OFF}")
            return cie, nome
        else:
            print(f"{C_VERM}CIE {cie} nao encontrado na lista de exemplo.{C_OFF}")
            confirmar = input("Deseja usar este CIE mesmo assim? (s/n): ").lower()
            if confirmar == 's':
                return cie, "Escola Nova / Nao Mapeada"


def executar_ciclo(cfg, banca, simular=False, cie_sessao=None, nome_escola=None):
    inicio = datetime.now(timezone.utc)

    # ---- 1. coleta ----
    print("\n[1/5] Lendo hardware da maquina...")
    inv = hw.coletar_tudo()
    disco = inv["disco"]

    serial = inv["serial_bios"]
    origem = inv.get("origem_serial") or ""
    if not serial:
        serial = disco.get("serial_disco") or ""
        origem = "disco (fallback)"

    if not serial:
        print(f"{C_VERM}      Nenhum identificador encontrado.{C_OFF}")
        if banca:
            banca.sinalizar("QUARENTENA")
        return None

    print(f"      Serial      : {serial}  ({origem})")
    print(f"      Modelo      : {inv['fabricante']} {inv['modelo_pc']}")
    print(f"      Vinculo     : CIE {cie_sessao} - {nome_escola}")

    # ---- 2. cadastro / quarentena ----
    print("\n[2/5] Consultando cadastro...")
    conhecida = None if simular else fb.buscar_maquina(serial)

    # Se ja conhecida, mantem o status ativo. Se nova, entra em quarentena
    # a menos que o tecnico esteja vinculando a uma escola valida agora.
    if conhecida:
        print(f"{C_VERDE}      Ja cadastrada: {conhecida.get('escola', '?')}{C_OFF}")
        status_cadastro = conhecida.get('status', 'ativo')
    else:
        print(f"{C_AMAR}      Nova maquina detectada.{C_OFF}")
        status_cadastro = "quarentena"

    # ---- 3. predicao ----
    print("\n[3/5] Calculando risco de falha do disco...")
    if disco["disponivel"]:
        anterior = None if simular else fb.ultima_leitura(serial)
        risco = prever_risco.calcular_risco(disco, anterior)
        faixa = risco["faixa"]
        cor = COR_FAIXA[faixa]
        print(f"      Risco em {risco['horizonte_dias']} dias : "
              f"{cor}{risco['risco_pct']}%  [{faixa}]{C_OFF}")
    else:
        risco = None
        faixa = "OK"
        print(f"{C_CINZA}      Sem SMART, sem predicao.{C_OFF}")

    # ---- 4. sinalizacao fisica ----
    print("\n[4/5] Sinalizando na bancada...")
    estado_led = "QUARENTENA" if status_cadastro == "quarentena" else faixa
    if banca:
        banca.sinalizar(estado_led,
                        risco=risco["risco"] if risco else None,
                        serial_maquina=serial)
        print(f"      LED -> {COR_FAIXA[estado_led]}{estado_led}{C_OFF}")

    # ---- 5. nuvem ----
    print("\n[5/5] Enviando para o Firestore...")
    registro = {
        "serial_bios": serial,
        "origem_serial": origem,
        "fabricante": inv["fabricante"],
        "modelo_pc": inv["modelo_pc"],
        "cie_escola": cie_sessao,
        "escola": nome_escola,
        "sistema_operacional": inv["sistema_operacional"],
        "cpu": inv["cpu"], "cpu_cores": inv["cpu_cores"],
        "ram_gb": inv["ram_gb"],
        "disco": disco,
        "risco_falha": risco["risco"] if risco else None,
        "risco_faixa": faixa,
        "status": status_cadastro,
        "id_bancada": cfg["id_bancada"],
        "ure": cfg["ure"],
        "operador": cfg["operador"],
    }

    if simular:
        print(f"{C_CINZA}      Modo simulacao - nada enviado.{C_OFF}")
    else:
        res = fb.salvar_maquina(registro)
        print(f"      {res}")
        fb.sincronizar_fila()

    dur = (datetime.now(timezone.utc) - inicio).total_seconds()
    print(f"\n{'-' * 66}")
    print(f"Ciclo concluido em {dur:.1f}s  |  CIE: {cie_sessao}  |  "
          f"{COR_FAIXA[estado_led]}{estado_led}{C_OFF}")
    print("-" * 66)
    return registro


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--loop", action="store_true")
    p.add_argument("--simular", action="store_true")
    p.add_argument("--porta", default=None)
    a = p.parse_args()

    cfg = carregar_config()
    cabecalho(cfg)

    banca = None
    if not a.simular:
        try:
            banca = arduino.Bancada(porta=a.porta or cfg.get("porta_serial"))
            banca.conectar()
        except Exception as e:
            print(f"{C_AMAR}Arduino offline: {e}{C_OFF}")

    try:
        cie, nome = solicitar_escola()

        if a.loop:
            print("\nModo bancada ativo. Ctrl+C para sair.")
            while True:
                input(f"\n>>> ENTER para ler maquina vinculada a {nome}... ")
                executar_ciclo(cfg, banca, a.simular, cie, nome)
        else:
            executar_ciclo(cfg, banca, a.simular, cie, nome)
    except KeyboardInterrupt:
        print("\nEncerrando.")
    finally:
        if banca:
            banca.fechar()


if __name__ == "__main__":
    sys.exit(main())
