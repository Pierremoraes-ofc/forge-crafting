# Contexto da Fase 2: Sistema de Mundo, Gizmo 3D & Targeting

## Objetivo
Modernizar a camada de interação no mundo do jogo do `forge-crafting`. Substituir o antigo sistema de colocação manual de props (baseado em raycast em loop e rotação via botões direcionais) pelo **Gizmo 3D** nativo do `pr_bridge` (`pr_lib.gizmo.await` / `pr_lib.fivem.gizmo.await`), garantir ciclo de vida seguro e sem vazamentos de memória para os objetos físicos das bancadas e implementar target (`pr_lib.target`) e blips condicionais sincronizados dinamicamente com as profissões e gangues dos jogadores.

## Escopo & Decisões Arquiteturais

1. **Gizmo 3D Modal (`WORLD-01`):**
   - Substituição de `updateModelPosition` e do bloco de posicionamento de `forge-crafting:CreateMenu` por um utilitário centralizado assíncrono que cria um prop de pré-visualização, congela colisões e invoca `pr_lib.gizmo.await`.
   - O Gizmo do `pr_bridge` oferece controle de eixos X/Y/Z, rotação completa em 3D, modo de precisão (tecla `TAB`), interface visual informativa e restauração automática ao cancelar.
   - Ao confirmar (`result.confirmed == true`), as coordenadas finais e heading/rotação são extraídos e salvos. Se cancelado, o prop temporário é descartado e o menu anterior é reaberto sem impacto no mundo.

2. **Zonas de Interação Target (`WORLD-02`):**
   - Todos os props spawnados são registrados diretamente via `pr_lib.target.addLocalEntity`.
   - Ao atualizar bancadas (`forge-crafting:Sync`) ou descarregar o recurso (`onResourceStop`), as entidades passam por `pr_lib.target.removeLocalEntity` antes de serem deletadas do jogo.

3. **Ciclo de Vida de Entidades (`WORLD-03`):**
   - Carregamento de modelos seguro com `pr_lib.fivem.streaming.requestModel` e liberação posterior via `releaseModel` / `SetModelAsNoLongerNeeded`.
   - Os props são criados com `CreateObjectNoOffset`, marcados como missão (`SetEntityAsMissionEntity`), invencíveis e congelados no chão.
   - Remoção rigorosa de quaisquer objetos órfãos.

4. **Blips Dinâmicos e Permissões (`WORLD-04`):**
   - Criação de blips apenas para jogadores que possuam o job ou gangue especificados na bancada (caso a restrição esteja ativa).
   - Suporte a atualização dinâmica de blips através dos eventos de transição de trabalho/gangue do framework (`pr_lib.framework.GetPlayerJob()`, `pr_lib.framework.GetPlayerGang()`).
