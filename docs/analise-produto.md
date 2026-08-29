# Análise de Produto — Bancada de Validação Física + Inventário Preditivo
**Contexto:** UNIVESP — PJI410 (Projeto Integrador em Computação IV)
**Tema oficial da disciplina:** "Desenvolver análise de dados em escala utilizando algum conjunto de dados existentes ou capturados por IoT e aprendizagem de máquina. Preparar uma interface para visualização dos resultados."

---

## 1. Resumo da ideia

Bancada física numa URE (Unidade Regional de Ensino). Técnico pluga o PC da escola na bancada. Fluxo:

1. Script local lê identidade e saúde do hardware (serial da BIOS, RAM, CPU, disco).
2. Script fala com Arduino BlackBoard UNO R3 via USB/Serial (UART). Arduino acende LED verde (máquina cadastrada) ou vermelho (desconhecida → quarentena).
3. Script empacota inventário e envia ao Firebase.
4. App Flutter consome Firebase em tempo real: painel de inventário, alertas, quarentena, relatório preditivo de troca de peça.

Divisão: hardware/firmware C++ no Arduino; software Flutter + Firebase.

## 2. Problema que resolve

Rede pública de ensino tem parque de PC grande, velho e mal documentado. Dores reais:

- Inventário em planilha, desatualizado, sem serial confiável.
- Máquina some ou troca de escola sem registro.
- Peça queima → troca reativa → laboratório parado semanas.
- Nenhum dado histórico para justificar orçamento de compra.

O produto troca inventário manual reativo por captura automática + previsão de falha.

## 3. Público-alvo

- **Primário:** técnico de campo da URE / Diretoria de Ensino.
- **Secundário:** gestor de TI da Secretaria (visão consolidada, orçamento).
- **Terciário:** direção da escola (status do laboratório).
- **Fora da escola:** prefeitura, hospital público, empresa com parque de 200+ PC, assistência técnica, empresa de renting de equipamento.

## 4. Análise de viabilidade

**Viabilidade técnica: ALTA.** Todas as peças são bem documentadas e gratuitas.

**Viabilidade de aderência ao tema da disciplina: MÉDIA — e esse é o risco sério do projeto.**

Sendo direto, sem amenizar: a ideia como está entrega **IoT + nuvem + interface**, mas quase não entrega **"análise de dados em escala" nem "aprendizagem de máquina"**, que são o núcleo do PJI410.

Três furos concretos:

| Furo | Por quê |
|---|---|
| **Não tem escala** | Uma URE tem talvez 300–2.000 PC. Um registro por PC = alguns milhares de linhas. Isso é planilha, não "dados em escala". |
| **Não tem dado para treinar ML** | "Relatório preditivo de substituição de peça" precisa de histórico de falhas rotulado. No dia 1 o banco está vazio. Modelo nenhum treina em zero exemplo. |
| **Arduino como "token de segurança" é teatro** | O script roda no PC do técnico. Quem controla o script controla a resposta. O Arduino não valida nada que o script não possa forjar. Bancar isso como "segurança física" numa defesa vai atrair pergunta ruim da banca. |

**Nenhum desses furos mata a ideia.** Todos têm correção barata — ver tópico 7. Com as correções a viabilidade vira ALTA em tudo.

**Riscos operacionais:**
- Ler serial de BIOS exige privilégio de administrador. Em PC de escola gerenciado, pode travar. Testar cedo.
- LGPD: dado de máquina, não de pessoa. Baixo risco. Mas não gravar nome de usuário logado nem hostname pessoal.
- Grupo leigo + 4 tecnologias novas (C++, Python, Flutter, ML) num semestre. Risco de cronograma é o maior risco real.

## 5. Pesquisa e análise de mercado

**Concorrentes diretos (inventário de TI):**
- **GLPI** — open source, padrão de fato no setor público brasileiro. Muita prefeitura e escola usa.
- **Snipe-IT** — open source, gestão de ativo, foco em ciclo de vida.
- **OCS Inventory NG** — agente que coleta hardware automático, integra com GLPI.
- **Lansweeper, ManageEngine AssetExplorer** — pagos, corporativos.

**O que nenhum deles faz bem (a sua brecha):**
1. **Nenhum tem bancada física com validação e sinalização por LED.** Todos assumem máquina ligada na rede. A bancada resolve o caso do PC que chegou sem rede, sem sistema, ou recém-formatado.
2. **Predição de falha de disco embutida é rara.** GLPI e Snipe-IT mostram idade do ativo, não probabilidade de falha.

**Dataset público que existe e resolve o furo do ML:**
- **Backblaze Hard Drive Test Data** — dado real de SMART de mais de 200 mil discos, publicado trimestralmente desde 2013, com rótulo de falha. Dezenas de milhões de linhas. É o dataset canônico de predição de falha de disco. Gratuito.
- **NASA/PCoE Bearing & Battery datasets** — alternativa para manutenção preditiva.

**Tendência de setor:** manutenção preditiva (predictive maintenance) e AIOps são as pautas quentes de gestão de ativo. Enquadrar o projeto assim dá narrativa forte na defesa.

## 6. Funcionalidades sugeridas

### MVP (o que garante nota)
- Script Python lê: serial BIOS, modelo/serial da placa-mãe, CPU, RAM (quantidade e pentes), disco (modelo, capacidade, **atributos SMART**).
- Handshake serial com Arduino: PC manda payload, Arduino responde e acende LED.
- Modelo de ML já treinado (offline, no dataset Backblaze) rodando local sobre os SMART do disco lido → devolve **risco de falha em 30 dias (0–100%)**.
- Envio para Firestore.
- App Flutter: lista de máquinas, ficha de cada uma, badge de risco (verde/amarelo/vermelho), tela de quarentena.
- Notebook Jupyter do treino do modelo (isso é peça de entrega, não bastidor — vai no relatório).

### Versão intermediária
- Sensor real no Arduino (DHT22 temperatura/umidade da bancada, ou sensor de corrente ACS712 no PC em teste) → série temporal, isso sim é IoT capturando dado.
- Histórico: gráfico de evolução do parque, idade média, distribuição de risco.
- Exportar relatório PDF para justificar orçamento.
- Autenticação Firebase por perfil (técnico / gestor).

### Versão avançada
- Retreino automático do modelo com falhas confirmadas pelos técnicos (loop de feedback).
- Múltiplas bancadas / múltiplas URE, comparativo regional.
- Sugestão automática de remanejamento: "PC #123 forte demais para uso administrativo, mandar para o laboratório de informática".
- QR Code impresso e colado na máquina.

## 7. Uso de Inteligência Artificial — o que é útil e o que é enfeite

### Útil de verdade

**A. Predição de falha de disco a partir de SMART.** Esta é a espinha dorsal e resolve os três furos do tópico 4 de uma vez.

Como funciona:
1. Baixa dataset Backblaze (milhões de linhas → **isso é a "análise de dados em escala"**).
2. Treina classificador (Random Forest ou Gradient Boosting) para prever falha usando atributos SMART: `SMART 5` (setores realocados), `SMART 187` (erros não corrigíveis), `SMART 197` (setores pendentes), `SMART 198` (erros incorrigíveis), `SMART 9` (horas ligado).
3. Salva o modelo (`joblib`).
4. Na bancada, o script lê o SMART do disco real via `smartctl`, joga no modelo, recebe probabilidade.

Resultado: ML **real**, treinado em dado **real e volumoso**, aplicado a hardware **físico**, exibido em **interface**. Cobre o enunciado da disciplina inteiro.

**B. Classificação de perfil de uso.** Clusterização (K-Means) das máquinas por CPU/RAM/disco → grupos "sucata", "administrativo", "laboratório". Simples, defensável, visual bonito no app.

**C. Detecção de anomalia no inventário.** Máquina cujo serial aparece com RAM diferente da última leitura = possível furto de peça. Regra simples resolve; não precisa de ML sofisticado, mas o alerta é valioso.

### Enfeite — não faça

- **Chatbot / LLM no app.** Zero valor aqui, custo de API, e desvia o foco da banca.
- **Rede neural profunda.** Random Forest ganha de deep learning em dado tabular desse tipo, treina em minuto, e é explicável. Deep learning aqui só adiciona risco.
- **Visão computacional lendo etiqueta.** Legal, fora de escopo, vai consumir o semestre.

## 8. Estrutura do sistema

**Perfis de usuário**
- Técnico: opera bancada, confirma quarentena, marca peça trocada.
- Gestor: só leitura + relatório consolidado.

**Telas do app Flutter**
1. Login
2. Dashboard (total de máquinas, em quarentena, em risco alto, gráfico de distribuição de risco)
3. Lista de inventário (busca por serial, filtro por escola / risco)
4. Ficha da máquina (hardware completo, histórico de leitura, gauge de risco de falha)
5. Quarentena (máquinas não cadastradas aguardando decisão)
6. Alertas / notificações

**Banco (Firestore) — coleções**

```
maquinas/{serial_bios}
  ├── modelo, fabricante, escola, ure
  ├── cpu: {modelo, cores, freq}
  ├── ram: {total_gb, pentes: []}
  ├── disco: {modelo, capacidade, tipo, smart: {...}}
  ├── risco_falha: 0.0-1.0
  ├── status: "ativo" | "quarentena" | "descartado"
  ├── ultima_leitura: timestamp
  └── leituras/{id}        (subcoleção = histórico)

bancadas/{id}
  └── nome, ure, ultimo_ping, token

eventos/{id}
  └── tipo, serial, timestamp, descricao
```

**Integrações:** Firebase Auth, Firestore, Cloud Messaging (push de quarentena).

**Segurança:** Firestore Security Rules por perfil. Nunca embutir credencial de admin no app Flutter — só no script local.

## 9. Tecnologia recomendada

| Camada | Escolha | Por quê |
|---|---|---|
| Firmware | C++ (Arduino IDE) | Já é o plano. Certo. |
| Script local | **Python 3** | Biblioteca pronta para tudo: serial, hardware, ML, Firebase. Não use C# nem Node aqui. |
| Leitura de hardware | `wmi` (Windows) / `dmidecode` (Linux) + **`smartctl`** (smartmontools) | `smartctl` é o que entrega os atributos SMART que alimentam o ML. É a peça-chave. |
| Serial | `pyserial` | Padrão. |
| ML | `pandas`, `scikit-learn`, `joblib` | Treino em Jupyter, modelo salvo em arquivo. |
| Nuvem | **Firebase Firestore** (plano Spark, gratuito) | Já é o plano. Tempo real de graça, integra nativo com Flutter. |
| App | **Flutter** | Já é o plano. **Recomendação:** compile primeiro para **Flutter Web**. Roda no navegador, sem emulador, sem loja, e a banca abre por link. Depois gera o APK se sobrar tempo. |
| Gráficos | `fl_chart` | Melhor pacote de gráfico do Flutter. |
| Versionamento | Git + GitHub | Exigência implícita do curso. Commit desde o dia 1. |

**Custo de infraestrutura: R$ 0,00.** Tudo cabe em free tier. Único gasto é o kit Arduino que o grupo já tem.

## 10. Modelo de monetização (se virasse produto real)

O PI não precisa monetizar, mas o relatório fica mais forte com um parágrafo disso:

- **Licença por ativo gerenciado** — R$ 1 a 3 por máquina/mês. Parque de 5.000 PC = R$ 5.000–15.000/mês.
- **Venda do kit bancada** — hardware + licença anual, modelo de venda para órgão público via pregão.
- **SaaS freemium** — até 50 máquinas grátis, cobra acima disso. Bom para PME e assistência técnica.
- **Serviço de implantação** — inventário inicial do parque como projeto pontual.
- **White label** — para empresa de renting de equipamento revender ao cliente final.

## 11. Análise financeira e de custos (cenário hipotético de produto)

**Custo do MVP acadêmico:** R$ 0 em software + kit Arduino (~R$ 150–250). Custo real do grupo é tempo: estimar 120–160 horas somadas.

**Se virasse produto comercial:**

| Item | Estimativa mensal |
|---|---|
| Firebase (até ~10 mil máquinas) | R$ 150–600 |
| Domínio + hospedagem do painel web | R$ 50 |
| Dev full stack pleno (1) | R$ 9.000–13.000 |
| Dev/analista de dados (0,5) | R$ 5.000–7.000 |
| Suporte/comercial (0,5) | R$ 3.000 |
| **Total operacional** | **~R$ 18.000–24.000** |

- **Ponto de equilíbrio:** a R$ 2/máquina/mês, precisa de ~10.000 máquinas ativas, ou seja 3 a 5 contratos de órgão público de porte médio.
- **Cenário conservador (ano 1):** 2 contratos, 4.000 máquinas → R$ 8.000/mês. Prejuízo, sobrevive com sócio trabalhando sem pró-labore.
- **Cenário realista (ano 2):** 6 contratos, 15.000 máquinas → R$ 30.000/mês. Equilíbrio atingido.
- **Cenário otimista:** contrato estadual único de 100.000 máquinas → R$ 200.000/mês.
- **Maior risco financeiro:** ciclo de venda para setor público é longo (6–18 meses) e depende de licitação. Queima caixa antes da primeira receita.
- **Redução de custo inicial:** começar em PME e assistência técnica (venda curta) enquanto o pipeline público amadurece.

## 12. Próximos passos recomendados

**Ordem sugerida de desenvolvimento — cada etapa validada antes da próxima:**

1. **Semana 1 — Prova de conceito de hardware.** Script Python lê serial da BIOS e SMART do disco no PC de um integrante. Se isso não funcionar por bloqueio de permissão, tudo muda. Testar primeiro.
2. **Semana 2 — Handshake Arduino.** Python manda string por serial, Arduino responde e acende LED. Isolado, sem nuvem.
3. **Semana 3–4 — Notebook de ML.** Baixar Backblaze, limpar, treinar, avaliar, salvar `modelo.joblib`. Esta é a entrega que garante a aderência ao tema da disciplina — não deixar por último.
4. **Semana 5 — Integração local.** Script lê hardware, consulta modelo, decide, fala com Arduino.
5. **Semana 6 — Firebase.** Enviar o pacote para o Firestore.
6. **Semana 7–9 — Flutter Web.** Dashboard, lista, ficha, quarentena.
7. **Semana 10 — Polimento, testes, vídeo, relatório.**

**Decisão que precisa ser tomada agora, antes de qualquer código:** o grupo aceita adicionar o pilar de ML sobre dataset público (Backblaze + SMART)? Sem isso o projeto entrega IoT e app bonito, mas não entrega o núcleo do PJI410.
