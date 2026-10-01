# Pesquisa e Arquitetura: Fase 5 - Nova NUI da Bancada de Craft

## Objetivo da Fase
Desenvolver e integrar uma interface NUI imersiva, moderna e responsiva para a bancada de trabalho no **forge-crafting**, substituindo o menu de contexto padrão dos jogadores. A interface permitirá visualizar o catálogo de receitas da bancada, insumos necessários (com contagem atual do inventário vs requerida), nível de maestria exigido, tempo de fabricação e botão de ação para iniciar o processo seguro de criação.

---

## 1. Referência Visual & Requisitos
- **Estilo Visual:** Dark glassmorphism com acentos metálicos e neon Forge-Core, sem dependências de frameworks pesados (Vanilla JS + Modern CSS3, garantindo carregamento instantâneo no CEF do FiveM).
- **Layout Geral:**
  - **Header:** Título da Bancada (ex: "Bancada de Armas", "Oficina Mecânica"), nível de maestria do jogador (`Nível X` ou `Maestria`), barra de busca dinâmica e botão fechar [x].
  - **Coluna Esquerda (Catálogo de Receitas):** Lista com scroll estilizado contendo cards compactos das receitas disponíveis. Cada card exibe ícone do item, nome, tempo e tag indicando disponibilidade (verde = disponível, vermelho = insumos insuficientes, cinza = nível bloqueado).
  - **Coluna Direita (Detalhes do Item Selecionado):**
    - Ícone ampliado do item com badge de quantidade produzida (ex: `x1`, `x5`).
    - Nome do item e tempo de preparo em segundos.
    - Status de Maestria: Exibição clara de `Nível Necessário` vs `Seu Nível Atual`.
    - Lista de Insumos / Materiais Requeridos:
      - Para cada ingrediente: ícone do item, nome legível e indicador numérico `Possui / Requerido` com coloração dinâmica (verde quando `possui >= requerido`, vermelho caso contrário).
    - Botão de Ação: `FABRICAR ITEM` (habilitado apenas se atender a todos os requisitos de insumo e nível; desabilitado com visual contrastante quando bloqueado).

---

## 2. Carregamento de Imagens e Compatibilidade
- FiveM NUI permite carregar imagens de outros recursos com URLs no formato:
  - `https://cfx-nui-<resourceName>/<subpath>/<item>.png`
  - Ou caminhos configurados via `Config.ImagePath`.
- Para evitar quebras caso o item não possua ícone registrado no inventário em uso, o front-end implementará `onerror` com fallback para um SVG elegante de caixa/ferramenta, garantindo que a UI nunca quebre visualmente.

---

## 3. Comunicação Bidirecional NUI ↔ Client FiveM
- **Abertura (`action: "open"`):**
  - O client dispara `SendNUIMessage({ action = "open", bench = {...}, items = {...}, playerLevel = ..., imagePath = ... })`.
  - Ativa foco: `SetNuiFocus(true, true)`.
- **Fechamento (`close`):**
  - O jogador pode clicar no botão fechar ou pressionar a tecla `ESC`.
  - Dispara callback NUI `fetch('https://forge-crafting/close')`.
  - O client chama `SetNuiFocus(false, false)` e restaura a visualização normal.
- **Início da Fabricação (`craft`):**
  - Ao clicar em "Fabricar", o JS envia o payload da receita selecionada via `fetch('https://forge-crafting/craft', { body: JSON.stringify(...) })`.
  - O client fecha a NUI (`SetNuiFocus(false, false)`), desativa a câmera orbital se ativa, e invoca o evento autoritativo da Fase 4 `forge-crafting:CraftCertainItem` com barra de progresso e validações de integridade.

---

## 4. Divisão dos Planos da Fase 5
1. **05-01-PLAN.md**: Construção dos componentes de front-end NUI (`html/index.html`, `html/css/style.css`, `html/js/app.js`) e declaração de manifesto em `fxmanifest.lua`.
2. **05-02-PLAN.md**: Conexão do client Lua com a NUI, busca dinâmica de insumos no inventário via `pr_lib.inventory`, handlers de foco e disparo do pipeline de fabricação.
