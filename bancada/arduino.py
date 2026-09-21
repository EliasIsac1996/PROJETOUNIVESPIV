"""
arduino.py
==========
Comunicacao serial (UART sobre USB) entre o script da bancada e a BlackBoard UNO R3.

PROTOCOLO (uma linha JSON por mensagem, terminada em \n, 9600 baud):

  PC -> Arduino
    {"cmd":"PING"}
    {"cmd":"STATUS","estado":"OK|ATENCAO|CRITICO|QUARENTENA","risco":0.82,"serial":"BR123"}
    {"cmd":"RESET"}

  Arduino -> PC
    {"ok":true,"bancada":"URE-01-B1","fw":"1.0.0"}
    {"ok":true,"led":"vermelho","bancada":"URE-01-B1"}

HONESTIDADE TECNICA (importante para a defesa do PI):
Isto NAO e seguranca criptografica. O Arduino confirma que existe uma bancada
fisica autorizada plugada na USB e sinaliza o resultado nos LEDs. Um operador com
acesso ao codigo consegue simular a resposta. O papel real do Arduino aqui e
INTERLOCK OPERACIONAL e SINALIZACAO FISICA, nao autenticacao forte.
Chame assim no relatorio. Se a banca perguntar, essa e a resposta certa.
"""

import json
import time

import serial
import serial.tools.list_ports

BAUD = 9600
TIMEOUT = 3.0


class BancadaNaoEncontrada(Exception):
    pass


def listar_portas():
    """Lista as portas seriais visiveis, para debug."""
    return [(p.device, p.description) for p in serial.tools.list_ports.comports()]


def detectar_porta():
    """
    Procura automaticamente a porta do Arduino.
    Reconhece os VID/PID mais comuns de UNO e clones (CH340, FTDI, CP210x).
    """
    candidatos = []
    for p in serial.tools.list_ports.comports():
        desc = f"{p.description} {p.manufacturer or ''}".lower()
        if any(t in desc for t in ("arduino", "ch340", "ch341", "usb-serial",
                                   "wch", "ftdi", "usb2.0-serial", "blackboard", "cp210")):
            candidatos.append(p.device)
    if not candidatos:
        raise BancadaNaoEncontrada(
            "Nenhuma porta de Arduino encontrada.\n"
            "Portas disponiveis: " + str(listar_portas()) + "\n"
            "Dicas: confira o cabo USB (tem cabo so de carga, sem dados), "
            "instale o driver CH340 se for clone, e feche o Serial Monitor "
            "da Arduino IDE - ele trava a porta."
        )
    return candidatos[0]


class Bancada:
    """Conexao com o Arduino. Use como context manager."""

    def __init__(self, porta=None, baud=BAUD, timeout=TIMEOUT):
        self.porta = porta or detectar_porta()
        self.baud = baud
        self.timeout = timeout
        self.ser = None
        self.id_bancada = None
        self.firmware = None

    def __enter__(self):
        self.conectar()
        return self

    def __exit__(self, *exc):
        self.fechar()

    def conectar(self):
        self.ser = serial.Serial(self.porta, self.baud, timeout=self.timeout)
        # o UNO reinicia quando a porta serial abre; esperar o boot
        time.sleep(2.2)
        self.ser.reset_input_buffer()
        resp = self.enviar({"cmd": "PING"})
        if not resp or not resp.get("ok"):
            raise BancadaNaoEncontrada(
                f"Porta {self.porta} abriu mas nao respondeu ao PING. "
                "O firmware bancada_token.ino esta gravado no Arduino?"
            )
        self.id_bancada = resp.get("bancada")
        self.firmware = resp.get("fw")
        return self

    def enviar(self, payload, tentativas=2):
        """Manda um dict como linha JSON e devolve a resposta como dict."""
        linha = (json.dumps(payload, separators=(",", ":")) + "\n").encode()
        for _ in range(tentativas):
            self.ser.reset_input_buffer()
            self.ser.write(linha)
            self.ser.flush()
            bruto = self.ser.readline().decode(errors="ignore").strip()
            if not bruto:
                continue
            try:
                return json.loads(bruto)
            except json.JSONDecodeError:
                continue  # provavelmente ruido do boot; tenta de novo
        return None

    def sinalizar(self, estado, risco=None, serial_maquina=None):
        """
        estado: 'OK' | 'ATENCAO' | 'CRITICO' | 'QUARENTENA'
        Acende o LED correspondente na bancada.
        """
        return self.enviar({
            "cmd": "STATUS",
            "estado": estado,
            "risco": round(float(risco), 3) if risco is not None else None,
            "serial": serial_maquina,
        })

    def resetar(self):
        return self.enviar({"cmd": "RESET"})

    def fechar(self):
        if self.ser and self.ser.is_open:
            try:
                self.resetar()
            except Exception:
                pass
            self.ser.close()


if __name__ == "__main__":
    print("Portas seriais visiveis:")
    for dev, desc in listar_portas():
        print(f"  {dev}  -  {desc}")
    print()

    try:
        with Bancada() as b:
            print(f"Conectado em {b.porta}")
            print(f"Bancada  : {b.id_bancada}")
            print(f"Firmware : {b.firmware}\n")

            for estado in ["OK", "ATENCAO", "CRITICO", "QUARENTENA"]:
                print(f"  testando LED -> {estado}")
                print("   ", b.sinalizar(estado, risco=0.5, serial_maquina="TESTE01"))
                time.sleep(1.5)

            print("\nTeste concluido.")
    except BancadaNaoEncontrada as e:
        print(f"ERRO: {e}")
