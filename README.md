# INVENTÁRIO — Bancada de Inventário Preditivo e Validação Física

**UNIVESP — PJI410 · Projeto Integrador em Computação IV**

O **INVENTÁRIO** é uma solução de hardware e software para gestão de ativos tecnológicos. O sistema identifica computadores, realiza uma análise preditiva da saúde do hardware via Inteligência Artificial e centraliza os dados na nuvem para gestão em tempo real.

---

## 🎯 Objetivo do Projeto
Automatizar o inventário técnico de unidades regionais, prevenindo interrupções de serviço através da **predição de falhas em discos rígidos (SSD/HDD)**. O sistema utiliza uma bancada física com Arduino para fornecer feedback visual imediato ao técnico sobre o estado do equipamento.

---

## 🚀 Guia de Início Rápido (Primeira Execução)

Se você acabou de clonar este repositório, siga esta ordem exata para colocar o sistema em operação:

### 1. Preparação do Ambiente
Certifique-se de ter o Python 3.10+ instalado.
```bash
# Instale as bibliotecas necessárias
pip install -r requirements.txt
```

### 2. Instalação do Smartmontools (Obrigatório)
O sistema depende do `smartctl` para ler a saúde do disco.
*   **Windows:** Execute no PowerShell como Administrador: `winget install smartmontools`
*   **Nota:** Se o comando `smartctl` não for reconhecido após a instalação, o script está configurado para procurá-lo automaticamente em `C:\Program Files\smartmontools\bin\`.

### 3. Treinamento da Inteligência Artificial
O modelo de predição não vem pré-treinado para economizar espaço. Você deve gerá-lo uma única vez:
```bash
cd ml
python gerar_dataset.py
python treinar_modelo.py
```
*Isso gerará o arquivo `modelo_falha_30d.joblib` na pasta `ml/modelo/`.*

### 4. Configuração do Arduino
1. Carregue o arquivo `firmware/bancada_token/bancada_token.ino` na sua placa Arduino (UNO ou similar).
2. O script detecta automaticamente a porta serial, incluindo drivers comuns como CH340 e CP210x.

### 5. Conexão com a Nuvem (Firebase)
1. Obtenha o arquivo de chave privada (`.json`) no Console do Firebase (Configurações > Contas de Serviço).
2. Renomeie o arquivo para `serviceAccountKey.json`.
3. Salve-o na pasta `/bancada/`.

---

## ⚙️ Fluxo de Operação Técnica

Para processar uma máquina na bancada, execute o orquestrador (sempre como **Administrador**):

```bash
cd bancada
python main.py
```

### O que acontece em cada etapa:
1.  **[1/5] Coleta de Identidade:** O sistema busca o Serial da BIOS. Caso não exista (PCs montados), ele gera um **UUID de Hardware** único para a máquina.
2.  **[2/5] Consulta de Cadastro:** O UUID é consultado no Firestore. Máquinas novas entram automaticamente em status de **Quarentena**.
3.  **[3/5] Predição de Risco:** Os dados SMART do disco são processados pelo modelo de Random Forest. O sistema calcula a probabilidade de falha nos próximos 30 dias.
4.  **[4/5] Sinalização Física:** O Python envia um comando JSON para o Arduino via Serial:
    *   🔵 **LED Verde:** Máquina Ativa + Risco Baixo.
    *   🟡 **LED Amarelo:** Risco Moderado (Atenção).
    *   🔴 **LED Vermelho:** Risco Crítico.
    *   🔄 **Alternado (Verm/Amar):** Máquina desconhecida (Quarentena).
5.  **[5/5] Sincronização Cloud:** O inventário completo (CPU, RAM, Disco, Risco) é enviado ao Firebase. Se estiver offline, os dados são salvos em uma fila SQLite local e sincronizados automaticamente na próxima conexão.

---

## 📊 Estrutura do Projeto

*   `/bancada`: Scripts de execução local (o "cérebro" da operação).
*   `/ml`: Pipeline de dados, geração de dataset sintético e treinamento do modelo.
*   `/firmware`: Código C++ para o Arduino.
*   `/app_flutter`: Aplicativo de gestão para visualização do inventário e aprovação de máquinas.

---

## ⚖️ Avisos Importantes para a Defesa (PI)

*   **Identificação Robusta:** O sistema é resiliente a hardwares sem número de série OEM, utilizando uma cadeia de fallback (BIOS -> UUID -> Disco).
*   **Fila Offline:** A bancada opera normalmente em locais sem internet, garantindo a integridade dos dados coletados através de sincronização posterior.
*   **Interlock Operacional:** O Arduino não provê segurança criptográfica, mas sim um interlock operacional e sinalização visual para o técnico em campo.
