/*
 * bancada_token.ino
 * =================
 * Firmware da BlackBoard UNO R3 (compativel Arduino UNO).
 *
 * Papel: interlock operacional e sinalizacao fisica da bancada de validacao.
 * Recebe o resultado da analise pelo PC (serial/UART) e acende o LED certo.
 *
 * LIGACAO (com resistor de 220 ohm em serie em cada LED):
 *   LED verde    -> pino  9  -> resistor -> GND
 *   LED amarelo  -> pino 10  -> resistor -> GND
 *   LED vermelho -> pino 11  -> resistor -> GND
 *   Buzzer (opcional) -> pino 8 -> GND
 *
 * PROTOCOLO (uma linha JSON por mensagem, 9600 baud):
 *   Recebe: {"cmd":"PING"}
 *           {"cmd":"STATUS","estado":"OK","risco":0.12,"serial":"BR123"}
 *           {"cmd":"RESET"}
 *   Responde: {"ok":true,"bancada":"URE-01-B1","fw":"1.0.0"}
 *
 * Nao usa biblioteca de JSON: a UNO tem 2 KB de RAM e as mensagens sao simples.
 * Parse manual por busca de substring e bem mais leve e nao quebra.
 *
 * NOTA PARA O RELATORIO: isto nao e autenticacao criptografica. O Arduino
 * confirma presenca de bancada fisica autorizada e sinaliza o estado. Chamar
 * de "token de seguranca forte" seria impreciso - a banca pode questionar.
 */

const char BANCADA_ID[] = "URE-01-BANCADA-01";
const char FIRMWARE[]   = "1.0.0";

const uint8_t LED_VERDE    = 9;
const uint8_t LED_AMARELO  = 10;
const uint8_t LED_VERMELHO = 11;
const uint8_t BUZZER       = 8;

const unsigned long TIMEOUT_OCIOSO = 120000UL;  // 2 min sem comando -> repouso

String buffer = "";
unsigned long ultimoComando = 0;
bool emRepouso = true;

// ---------------------------------------------------------------------------
// LEDs
// ---------------------------------------------------------------------------

void apagarTudo() {
  digitalWrite(LED_VERDE, LOW);
  digitalWrite(LED_AMARELO, LOW);
  digitalWrite(LED_VERMELHO, LOW);
}

void bipe(uint8_t vezes, uint16_t duracao) {
  for (uint8_t i = 0; i < vezes; i++) {
    tone(BUZZER, 2000, duracao);
    delay(duracao + 90);
  }
}

// Respiracao suave no verde = bancada ligada e ociosa
void respirar() {
  static int brilho = 0;
  static int passo = 2;
  static unsigned long ultimo = 0;
  if (millis() - ultimo < 22) return;
  ultimo = millis();
  brilho += passo;
  if (brilho >= 60 || brilho <= 0) passo = -passo;
  analogWrite(LED_VERDE, brilho);
}

void piscar(uint8_t pino, uint8_t vezes, uint16_t ms) {
  for (uint8_t i = 0; i < vezes; i++) {
    digitalWrite(pino, HIGH);
    delay(ms);
    digitalWrite(pino, LOW);
    delay(ms);
  }
}

// ---------------------------------------------------------------------------
// Parse manual do JSON
// ---------------------------------------------------------------------------

String extrairTexto(const String &json, const String &chave) {
  int i = json.indexOf("\"" + chave + "\"");
  if (i < 0) return "";
  int abre = json.indexOf('"', json.indexOf(':', i) + 1);
  if (abre < 0) return "";
  int fecha = json.indexOf('"', abre + 1);
  if (fecha < 0) return "";
  return json.substring(abre + 1, fecha);
}

float extrairNumero(const String &json, const String &chave) {
  int i = json.indexOf("\"" + chave + "\"");
  if (i < 0) return -1.0;
  int dp = json.indexOf(':', i);
  if (dp < 0) return -1.0;
  return json.substring(dp + 1).toFloat();
}

// ---------------------------------------------------------------------------
// Comandos
// ---------------------------------------------------------------------------

void responder(const String &led) {
  Serial.print("{\"ok\":true,\"led\":\"");
  Serial.print(led);
  Serial.print("\",\"bancada\":\"");
  Serial.print(BANCADA_ID);
  Serial.println("\"}");
}

void aplicarEstado(const String &estado, float risco) {
  apagarTudo();
  emRepouso = false;

  if (estado == "OK") {
    digitalWrite(LED_VERDE, HIGH);
    bipe(1, 90);
    responder("verde");

  } else if (estado == "ATENCAO") {
    digitalWrite(LED_AMARELO, HIGH);
    bipe(2, 90);
    responder("amarelo");

  } else if (estado == "CRITICO") {
    piscar(LED_VERMELHO, 6, 130);
    digitalWrite(LED_VERMELHO, HIGH);
    bipe(3, 140);
    responder("vermelho");

  } else if (estado == "QUARENTENA") {
    // alterna vermelho/amarelo: visual distinto de "disco ruim"
    for (uint8_t i = 0; i < 5; i++) {
      digitalWrite(LED_VERMELHO, HIGH);
      digitalWrite(LED_AMARELO, LOW);
      delay(180);
      digitalWrite(LED_VERMELHO, LOW);
      digitalWrite(LED_AMARELO, HIGH);
      delay(180);
    }
    digitalWrite(LED_AMARELO, LOW);
    digitalWrite(LED_VERMELHO, HIGH);
    bipe(4, 110);
    responder("vermelho");

  } else {
    Serial.print("{\"ok\":false,\"erro\":\"estado desconhecido\",\"recebido\":\"");
    Serial.print(estado);
    Serial.println("\"}");
    return;
  }

  (void)risco;  // disponivel para uso futuro (ex: barra de LED, PWM proporcional)
}

void processar(const String &linha) {
  ultimoComando = millis();
  String cmd = extrairTexto(linha, "cmd");

  if (cmd == "PING") {
    Serial.print("{\"ok\":true,\"bancada\":\"");
    Serial.print(BANCADA_ID);
    Serial.print("\",\"fw\":\"");
    Serial.print(FIRMWARE);
    Serial.println("\"}");

  } else if (cmd == "STATUS") {
    aplicarEstado(extrairTexto(linha, "estado"), extrairNumero(linha, "risco"));

  } else if (cmd == "RESET") {
    apagarTudo();
    emRepouso = true;
    Serial.println("{\"ok\":true,\"led\":\"repouso\"}");

  } else {
    Serial.println("{\"ok\":false,\"erro\":\"comando desconhecido\"}");
  }
}

// ---------------------------------------------------------------------------

void setup() {
  pinMode(LED_VERDE, OUTPUT);
  pinMode(LED_AMARELO, OUTPUT);
  pinMode(LED_VERMELHO, OUTPUT);
  pinMode(BUZZER, OUTPUT);

  Serial.begin(9600);
  buffer.reserve(200);

  // autoteste visual no boot: confirma que os tres LEDs funcionam
  digitalWrite(LED_VERDE, HIGH);    delay(220);
  digitalWrite(LED_AMARELO, HIGH);  delay(220);
  digitalWrite(LED_VERMELHO, HIGH); delay(400);
  apagarTudo();

  ultimoComando = millis();
  emRepouso = true;
}

void loop() {
  while (Serial.available() > 0) {
    char c = (char)Serial.read();
    if (c == '\n') {
      if (buffer.length() > 0) processar(buffer);
      buffer = "";
    } else if (c != '\r' && buffer.length() < 190) {
      buffer += c;
    }
  }

  if (!emRepouso && (millis() - ultimoComando > TIMEOUT_OCIOSO)) {
    apagarTudo();
    emRepouso = true;
  }

  if (emRepouso) respirar();
}
