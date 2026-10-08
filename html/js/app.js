/* =====================================================
   Forge Crafting - Interface NUI Moderna de Bancada
   Lógica Vanilla JS para FiveM CEF
   Encapsulado em IIFE para isolamento total de escopo
   ===================================================== */

(function () {
    'use strict';

    var fallbackSvg = (window && window.FALLBACK_SVG) ||
        'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" width="36" height="36" viewBox="0 0 24 24" fill="none" stroke="%2364748b" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"></path><polyline points="3.27 6.96 12 12.01 20.73 6.96"></polyline><line x1="12" y1="22.08" x2="12" y2="12"></line></svg>';

    var benchData = null;
    var recipes = [];
    var filteredRecipes = [];
    var selectedRecipe = null;
    var playerLevel = 0;
    var baseImagePath = 'images/';

    // Elementos DOM
    var appContainer = document.getElementById('crafting-app');
    var standbyApp = document.getElementById('standby-app');
    var standbyLogo = document.getElementById('standby-logo');
    var standbyTitle = document.getElementById('standby-title');
    var standbySubtitle = document.getElementById('standby-subtitle');

    var benchTitle = document.getElementById('bench-title');
    var playerLevelVal = document.getElementById('player-level-val');
    var searchInput = document.getElementById('search-input');
    var btnClose = document.getElementById('btn-close');
    var recipesList = document.getElementById('recipes-list');
    var recipesCount = document.getElementById('recipes-count');

    // Elementos de Navegação e Abas
    var tabCrafting = document.getElementById('tab-crafting');
    var tabUpgrades = document.getElementById('tab-upgrades');
    var viewCrafting = document.getElementById('view-crafting');
    var viewUpgrades = document.getElementById('view-upgrades');

    // Elementos da Aba Upgrades
    var weaponsList = document.getElementById('weapons-list');
    var weaponsCount = document.getElementById('weapons-count');
    var weaponDetailEmpty = document.getElementById('weapon-detail-empty');
    var weaponDetailContent = document.getElementById('weapon-detail-content');
    var invComponentsToolbar = document.querySelector('.inv-components-toolbar');
    var invComponentsCount = document.getElementById('inv-components-count');
    var invComponentsList = document.getElementById('inv-components-list');
    var benchmatWeaponTitle = document.getElementById('benchmat-weapon-title');
    var specSerial = document.getElementById('spec-serial');
    var specAmmo = document.getElementById('spec-ammo');
    var specDurability = document.getElementById('spec-durability');

    // Popover Seletor de Acessórios
    var compPickerPopover = document.getElementById('comp-picker-popover');
    var popoverTitle = document.getElementById('popover-title');
    var btnPopoverClose = document.getElementById('btn-popover-close');
    var popoverItemsList = document.getElementById('popover-items-list');

    // Estado da Aba Upgrades
    var currentTab = 'crafting';
    var weapons = [];
    var filteredWeapons = [];
    var selectedWeapon = null;
    var activeWeaponPropKey = null;
    var inventoryAttachments = [];
    var availableTints = [];
    var activePopoverSlot = null;

    var detailEmpty = document.getElementById('recipe-detail-empty');
    var detailContent = document.getElementById('recipe-detail-content');
    var detailImage = document.getElementById('detail-image');
    var detailAmount = document.getElementById('detail-amount');
    var detailTitle = document.getElementById('detail-title');
    var detailTime = document.getElementById('detail-time');
    var detailXp = document.getElementById('detail-xp');
    var detailXpMeta = document.getElementById('detail-xp-meta');
    var detailLevelReq = document.getElementById('detail-level-req');
    var detailLevelMeta = document.getElementById('detail-level-meta');
    var ingredientsGrid = document.getElementById('ingredients-grid');
    var materialsStatus = document.getElementById('materials-status');
    var statusWarning = document.getElementById('status-warning');
    var warningMessage = document.getElementById('warning-message');
    var btnCraft = document.getElementById('btn-craft');

    var ITEM_ALIASES_JS = {
        'ferro': 'iron',
        'iron': 'iron',
        'metal': 'metalscrap',
        'metalscrap': 'metalscrap',
        'sucata': 'metalscrap',
        'scrap': 'metalscrap',
        'scrapmetal': 'metalscrap',
        'ouro': 'gold',
        'gold': 'gold',
        'cobre': 'copper',
        'copper': 'copper',
        'aluminio': 'aluminum',
        'aluminum': 'aluminum',
        'plastico': 'plastic',
        'plastic': 'plastic',
        'borracha': 'rubber',
        'rubber': 'rubber',
        'vidro': 'glass',
        'glass': 'glass',
        'aco': 'steel',
        'steel': 'steel',
        'madeira': 'wood',
        'wood': 'wood',
    };

    function normalizeImageUrl(url) {
        var value = String(url || '').trim();
        var match = value.match(/^nui:\/\/([^/]+)\/(.*)$/i);
        if (match) return 'https://cfx-nui-' + match[1] + '/' + match[2];
        return value;
    }

    // Helper inteligente para tratar erro de imagem
    function handleImageError(img) {
        if (!img) return;
        var currentSrc = img.src || '';
        var step = Number(img.dataset.errorStep || 0);

        // Passo 1: Se falhou na pasta local images/, tenta via ox_inventory na FiveM
        if (step === 0) {
            img.dataset.errorStep = '1';
            var itemKey = String(img.dataset.itemName || '').toLowerCase();
            var fileName = (typeof ATTACHMENT_IMAGES !== 'undefined' && ATTACHMENT_IMAGES[itemKey])
                || currentSrc.substring(currentSrc.lastIndexOf('/') + 1).split('?')[0];
            img.src = 'https://cfx-nui-ox_inventory/web/images/' + fileName;
            return;
        }

        // Passo 2: Se falhou e possui alias mapeado (ex: ferro.png -> iron.png)
        if (step === 1) {
            img.dataset.errorStep = '2';
            var clean = currentSrc.substring(currentSrc.lastIndexOf('/') + 1).replace(/\.png$/, '').toLowerCase();
            if (ITEM_ALIASES_JS[clean] && ITEM_ALIASES_JS[clean] !== clean) {
                img.src = 'images/' + ITEM_ALIASES_JS[clean] + '.png';
                return;
            }
        }

        // Passo 3: Esgotou tentativas, exibe SVG de fallback
        img.onerror = null;
        img.src = fallbackSvg;
    }

    // Expor globalmente para tags <img onerror="handleImageError(this)">
    window.handleImageError = handleImageError;

    // Constrói URL da imagem do item (prioriza imagens locais em images/ com fallback para ox_inventory)
    function getItemImageUrl(itemName, itemObj) {
        var candidate = (itemObj && itemObj.image && itemObj.image !== '') ? itemObj.image : itemName;
        if (!candidate) return fallbackSvg;

        candidate = String(candidate).trim();

        // URLs do inventário devem permanecer na origem do inventário. Copiar
        // apenas o nome para images/ fazia o primeiro carregamento sempre falhar.
        if (candidate.startsWith('http://') || candidate.startsWith('https://') || candidate.startsWith('data:') || candidate.startsWith('nui://')) {
            return normalizeImageUrl(candidate);
        }

        // Limpar prefixos e extrair apenas o nome do arquivo
        var cleanName = candidate
            .replace(/^nui:\/\/[^/]+\/web\/images\//, '')
            .replace(/^nui:\/\/[^/]+\/html\/images\//, '')
            .replace(/^nui:\/\/[^/]+\//, '')
            .replace(/^images\//, '')
            .replace(/^.*[\\\/]/, '')
            .replace(/\.[^/.]+$/, '')
            .toLowerCase()
            .trim();

        // Normalizar aliases (ex: ferro -> iron, metal -> metalscrap, sucata -> metalscrap)
        if (ITEM_ALIASES_JS[cleanName]) {
            cleanName = ITEM_ALIASES_JS[cleanName];
        }

        // Retorna caminho relativo local (mesma origem HTTPS do DUI, 100% de sucesso)
        return 'images/' + cleanName + '.png';
    }

    // Formatação do nível
    function formatLevel(lvl) {
        if (typeof lvl === 'string' && lvl.toLowerCase() === 'maestria') {
            return 'Maestria';
        }
        var num = Number(lvl) || 0;
        if (num >= 999999) return 'Maestria';
        return 'Nível ' + num;
    }

    // Avalia a disponibilidade de uma receita
    function checkRecipeAvailability(recipe) {
        var levelNeeded = Number(recipe.level) || 0;
        var meetsLevel = playerLevel >= levelNeeded;

        var hasAllIngredients = true;
        var reqList = recipe.recipe || [];
        for (var i = 0; i < reqList.length; i++) {
            var ing = reqList[i];
            var required = Number(ing.amount) || 1;
            var owned = Number(ing.currentAmount != null ? ing.currentAmount : (ing.count != null ? ing.count : (ing.owned || 0)));
            if (owned < required) {
                hasAllIngredients = false;
                break;
            }
        }

        return {
            available: meetsLevel && hasAllIngredients,
            meetsLevel: meetsLevel,
            hasAllIngredients: hasAllIngredients,
            levelNeeded: levelNeeded
        };
    }

    // Renderiza a lista de receitas
    function renderRecipesList() {
        if (!recipesList) return;
        recipesList.innerHTML = '';
        if (recipesCount) recipesCount.textContent = filteredRecipes.length;

        if (filteredRecipes.length === 0) {
            recipesList.innerHTML =
                '<div style="padding: 24px; text-align: center; color: #64748b; font-size: 0.85rem;">' +
                'Nenhuma receita cadastrada nesta bancada.' +
                '</div>';
            showEmptyDetail();
            return;
        }

        filteredRecipes.forEach(function (recipe) {
            var availability = checkRecipeAvailability(recipe);
            var card = document.createElement('div');
            var isSelected = selectedRecipe && selectedRecipe.item === recipe.item;
            card.className = 'recipe-card ' + (isSelected ? 'active ' : '') + (!availability.meetsLevel ? 'locked' : '');

            var statusClass = 'available';
            var statusText = 'Disponível';

            if (!availability.meetsLevel) {
                statusClass = 'locked';
                statusText = 'Nível ' + availability.levelNeeded;
            } else if (!availability.hasAllIngredients) {
                statusClass = 'missing';
                statusText = 'Faltam Itens';
            }

            var imgUrl = getItemImageUrl(recipe.item, recipe);

            card.innerHTML =
                '<div class="recipe-card-img">' +
                '    <img src="' + imgUrl + '" alt="' + (recipe.item_label || recipe.item) + '" onerror="handleImageError(this)">' +
                '</div>' +
                '<div class="recipe-card-info">' +
                '    <div class="recipe-card-title">' + (recipe.item_label || recipe.item) + '</div>' +
                '    <div class="recipe-card-meta">' +
                '        <span class="status-badge ' + statusClass + '">' + statusText + '</span>' +
                '        <span>' + (recipe.time || 0) + 's</span>' +
                '    </div>' +
                '</div>';

            // Sempre permitir inspecionar a receita (mostrar ingredientes e requisitos)
            function onCardSelect(e) {
                if (e) {
                    if (e.preventDefault) e.preventDefault();
                    if (e.stopPropagation) e.stopPropagation();
                }
                selectRecipe(recipe);
            }
            card.addEventListener('mousedown', onCardSelect);
            card.addEventListener('click', onCardSelect);

            recipesList.appendChild(card);
        });

        // Se houver receitas, seleciona a primeira receita acessível ou a primeira disponível
        if (filteredRecipes.length > 0) {
            var isSelectedStillValid = selectedRecipe && filteredRecipes.some(function (r) {
                return r.item === selectedRecipe.item;
            });
            if (!isSelectedStillValid) {
                var firstAvailable = filteredRecipes.find(function (r) {
                    return checkRecipeAvailability(r).available;
                }) || filteredRecipes[0];
                selectRecipe(firstAvailable);
            }
        } else {
            showEmptyDetail();
        }
    }

    // Seleciona e exibe detalhes de uma receita
    function selectRecipe(recipe) {
        if (!recipe) return;
        selectedRecipe = recipe;

        // Atualiza estado ativo nos cards
        if (recipesList) {
            var cards = recipesList.querySelectorAll('.recipe-card');
            cards.forEach(function (card, index) {
                if (filteredRecipes[index] && filteredRecipes[index].item === recipe.item) {
                    card.classList.add('active');
                } else {
                    card.classList.remove('active');
                }
            });
        }

        var availability = checkRecipeAvailability(recipe);

        if (detailEmpty) detailEmpty.style.display = 'none';
        if (detailContent) detailContent.style.display = 'flex';

        if (detailTitle) detailTitle.textContent = recipe.item_label || recipe.item;
        if (detailAmount) detailAmount.textContent = 'x' + (recipe.amount || 1);
        if (detailTime) detailTime.textContent = (recipe.time || 0) + 's';
        if (detailImage) detailImage.src = getItemImageUrl(recipe.item, recipe);

        if (detailXp) {
            var xpReward = Number(recipe.xp) || 10;
            detailXp.textContent = '+' + xpReward + ' XP';
        }

        var levelNeeded = Number(recipe.level) || 0;
        if (detailLevelMeta && detailLevelReq) {
            if (levelNeeded > 0) {
                detailLevelMeta.style.display = 'flex';
                detailLevelReq.textContent = formatLevel(levelNeeded);
                detailLevelReq.style.color = (playerLevel < levelNeeded) ? '#f87171' : '#38bdf8';
            } else {
                detailLevelMeta.style.display = 'none';
            }
        }

        // Renderiza ingredientes
        if (ingredientsGrid) {
            ingredientsGrid.innerHTML = '';
            var ingredients = recipe.recipe || [];

            ingredients.forEach(function (ing) {
                var required = Number(ing.amount) || 1;
                var owned = Number(ing.currentAmount != null ? ing.currentAmount : (ing.count != null ? ing.count : (ing.owned || 0)));
                var isSufficient = owned >= required;
                var ingImgUrl = getItemImageUrl(ing.item, ing);

                var ingCard = document.createElement('div');
                ingCard.className = 'ingredient-card ' + (isSufficient ? 'sufficient' : 'insufficient');
                ingCard.innerHTML =
                    '<div class="ingredient-img">' +
                    '    <img src="' + ingImgUrl + '" alt="' + (ing.label || ing.item) + '" onerror="handleImageError(this)">' +
                    '</div>' +
                    '<div class="ingredient-info">' +
                    '    <div class="ingredient-name">' + (ing.label || ing.item) + '</div>' +
                    '    <div class="ingredient-count ' + (isSufficient ? 'sufficient' : 'insufficient') + '">' +
                    owned + ' / ' + required +
                    '    </div>' +
                    '</div>';
                ingredientsGrid.appendChild(ingCard);
            });
        }

        // Atualiza botão de ação e avisos
        if (btnCraft && materialsStatus && statusWarning && warningMessage) {
            if (availability.available) {
                materialsStatus.textContent = 'Pronto para forjar';
                materialsStatus.style.color = '#4ade80';
                statusWarning.style.display = 'none';
                btnCraft.disabled = false;
            } else {
                btnCraft.disabled = true;
                statusWarning.style.display = 'flex';

                if (!availability.meetsLevel) {
                    materialsStatus.textContent = 'Nível de maestria insuficiente';
                    materialsStatus.style.color = '#f87171';
                    warningMessage.textContent = 'Requer ' + formatLevel(levelNeeded);
                } else {
                    materialsStatus.textContent = 'Materiais em falta';
                    materialsStatus.style.color = '#f87171';
                    warningMessage.textContent = 'Insumos insuficientes no inventário';
                }
            }
        }
    }

    function showEmptyDetail() {
        selectedRecipe = null;
        if (detailEmpty) detailEmpty.style.display = 'flex';
        if (detailContent) detailContent.style.display = 'none';
    }

    // =====================================================
    //  Configurações do Sistema de Upgrades de Armas
    // =====================================================

    var SLOTS_CONFIG = [
        {
            id: 'suppressor',
            label: 'Cano / Silenciador',
            shortLabel: 'Silenciador',
            icon: '<svg viewBox="0 0 24 24" width="28" height="28" stroke="currentColor" stroke-width="1.8" fill="none"><rect x="3" y="10" width="18" height="4" rx="1"></rect><line x1="7" y1="10" x2="7" y2="14"></line><line x1="11" y1="10" x2="11" y2="14"></line></svg>'
        },
        {
            id: 'scope',
            label: 'Mira / Óptica',
            shortLabel: 'Mira Óptica',
            icon: '<svg viewBox="0 0 24 24" width="28" height="28" stroke="currentColor" stroke-width="1.8" fill="none"><circle cx="12" cy="12" r="7"></circle><line x1="12" y1="2" x2="12" y2="5"></line><line x1="12" y1="19" x2="12" y2="22"></line><line x1="2" y1="12" x2="5" y2="12"></line><line x1="19" y1="12" x2="22" y2="12"></line><circle cx="12" cy="2" r="2"></circle></svg>'
        },
        {
            id: 'flashlight',
            label: 'Lanterna / Tático',
            shortLabel: 'Lanterna Tática',
            icon: '<svg viewBox="0 0 24 24" width="28" height="28" stroke="currentColor" stroke-width="1.8" fill="none"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"></polygon></svg>'
        },
        {
            id: 'magazine',
            label: 'Carregador / Pente',
            shortLabel: 'Carregador',
            icon: '<svg viewBox="0 0 24 24" width="28" height="28" stroke="currentColor" stroke-width="1.8" fill="none"><rect x="6" y="4" width="12" height="16" rx="2"></rect><line x1="6" y1="8" x2="18" y2="8"></line><line x1="6" y1="12" x2="18" y2="12"></line><line x1="6" y1="16" x2="18" y2="16"></line></svg>'
        },
        {
            id: 'grip',
            label: 'Empunhadura / Grip',
            shortLabel: 'Grip Frontal',
            icon: '<svg viewBox="0 0 24 24" width="28" height="28" stroke="currentColor" stroke-width="1.8" fill="none"><path d="M7 4h10v3l-3 13H10L7 7V4z"></path></svg>'
        },
        {
            id: 'tint',
            label: 'Pintura / Camuflagem',
            shortLabel: 'Pintura & Skin',
            icon: '<svg viewBox="0 0 24 24" width="28" height="28" stroke="currentColor" stroke-width="1.8" fill="none"><path d="M12 2.69l5.66 5.66a8 8 0 1 1-11.31 0z"></path></svg>'
        }
    ];

    var TINTS_LIST = [
        { id: 0, label: 'Padrão / Original', color: '#64748b' },
        { id: 1, label: 'Verde Militar',      color: '#22c55e' },
        { id: 2, label: 'Ouro Luxo',          color: '#eab308' },
        { id: 3, label: 'Rosa Chiclete',      color: '#ec4899' },
        { id: 4, label: 'Camuflagem Urbana',  color: '#94a3b8' },
        { id: 5, label: 'Policial LSPD',      color: '#3b82f6' },
        { id: 6, label: 'Laranja Tático',     color: '#f97316' },
        { id: 7, label: 'Platina Cromo',      color: '#e2e8f0' }
    ];

    function getComponentSlot(name) {
        if (!name) return 'suppressor';
        var s = String(name).toLowerCase();
        if (s.indexOf('supp') !== -1 || s.indexOf('silenc') !== -1 || s.indexOf('barrel') !== -1 || s.indexOf('muzzle') !== -1 || s.indexOf('compensator') !== -1) return 'suppressor';
        if (s.indexOf('scope') !== -1 || s.indexOf('sight') !== -1 || s.indexOf('optic') !== -1 || s.indexOf('holo') !== -1 || s.indexOf('mira') !== -1) return 'scope';
        if (s.indexOf('flsh') !== -1 || s.indexOf('flash') !== -1 || s.indexOf('laser') !== -1 || s.indexOf('lanterna') !== -1 || s.indexOf('tactical') !== -1) return 'flashlight';
        if (s.indexOf('clip') !== -1 || s.indexOf('mag') !== -1 || s.indexOf('drum') !== -1 || s.indexOf('pente') !== -1 || s.indexOf('carregador') !== -1) return 'magazine';
        if (s.indexOf('grip') !== -1 || s.indexOf('afgrip') !== -1 || s.indexOf('handle') !== -1 || s.indexOf('empunhadura') !== -1) return 'grip';
        if (s.indexOf('tint') !== -1 || s.indexOf('skin') !== -1 || s.indexOf('camo') !== -1 || s.indexOf('pintura') !== -1) return 'tint';
        return 'suppressor';
    }

    function formatComponentLabel(name) {
        if (!name) return '';
        var clean = String(name).replace(/^at_/i, '').replace(/^component_/i, '').replace(/_/g, ' ');
        return clean.charAt(0).toUpperCase() + clean.slice(1);
    }

    var ATTACHMENT_IMAGES = {
        'at_suppressor_heavy': 'at_suppressor.png',
        'at_suppressor_light': 'at_suppressor.png',
        'at_suppressor': 'at_suppressor.png',
        'at_clip_extended_rifle': 'at_clip_extended2.png',
        'at_clip_extended_pistol': 'at_clip_extended.png',
        'at_clip_extended_smg': 'at_clip_extended.png',
        'at_clip_extended_mg': 'at_clip_drum.png',
        'at_clip_extended_shotgun': 'at_clip_extended2.png',
        'at_clip_extended_sniper': 'at_clip_extended2.png',
        'at_clip_drum_rifle': 'at_clip_drum.png',
        'at_clip_drum_smg': 'at_clip_drum.png',
        'at_clip_drum_shotgun': 'at_clip_drum.png',
        'at_flashlight': 'at_flashlight.png',
        'at_laser': 'at_flashlight.png',
        'at_grip': 'at_grip.png',
        'at_barrel': 'at_barrel.png',
        'at_compensator': 'at_muzzle_tactical.png',
        'at_scope_advanced': 'at_scope_advanced.png',
        'at_scope_holo': 'at_scope_holo.png',
        'at_scope_macro': 'at_scope_small.png',
        'at_scope_medium': 'at_scope_medium.png',
        'at_scope_large': 'at_scope_large.png',
        'at_scope_small': 'at_scope_small.png',
        'at_scope_nv': 'at_scope_nv.png',
        'at_scope_thermal': 'at_scope_thermal.png',
        'at_skin_camo': 'digicamo_attachment.png',
        'at_skin_boom': 'boomcamo_attachment.png',
        'at_skin_brushstroke': 'brushcamo_attachment.png',
        'at_skin_geometric': 'geocamo_attachment.png',
        'at_skin_leopard': 'leopardcamo_attachment.png',
        'at_skin_patriotic': 'patriotcamo_attachment.png',
        'at_skin_perseus': 'perseuscamo_attachment.png',
        'at_skin_sessanta': 'sessantacamo_attachment.png',
        'at_skin_skull': 'skullcamo_attachment.png',
        'at_skin_wood': 'woodcamo_attachment.png',
        'at_skin_zebra': 'zebracamo_attachment.png',
    };

    function resolveAttachmentImage(name) {
        if (!name) return 'images/at_suppressor.png';
        var clean = String(name).toLowerCase();

        if (inventoryAttachments && inventoryAttachments.length > 0) {
            for (var i = 0; i < inventoryAttachments.length; i++) {
                if (inventoryAttachments[i].name && inventoryAttachments[i].name.toLowerCase() === clean) {
                    if (inventoryAttachments[i].image && inventoryAttachments[i].image !== '') {
                        return normalizeImageUrl(inventoryAttachments[i].image);
                    }
                }
            }
        }

        var mappedFile = ATTACHMENT_IMAGES[clean];
        if (mappedFile) {
            return 'https://cfx-nui-ox_inventory/web/images/' + mappedFile;
        }

        if (clean.indexOf('supp') !== -1 || clean.indexOf('silenc') !== -1) {
            return 'https://cfx-nui-ox_inventory/web/images/at_suppressor.png';
        }
        if (clean.indexOf('flsh') !== -1 || clean.indexOf('flash') !== -1 || clean.indexOf('laser') !== -1) {
            return 'https://cfx-nui-ox_inventory/web/images/at_flashlight.png';
        }
        if (clean.indexOf('scope') !== -1 || clean.indexOf('sight') !== -1 || clean.indexOf('holo') !== -1) {
            return 'https://cfx-nui-ox_inventory/web/images/at_scope_small.png';
        }
        if (clean.indexOf('drum') !== -1) {
            return 'https://cfx-nui-ox_inventory/web/images/at_clip_drum.png';
        }
        if (clean.indexOf('clip') !== -1 || clean.indexOf('mag') !== -1) {
            return 'https://cfx-nui-ox_inventory/web/images/at_clip_extended.png';
        }
        if (clean.indexOf('grip') !== -1) {
            return 'https://cfx-nui-ox_inventory/web/images/at_grip.png';
        }
        if (clean.indexOf('skin') !== -1 || clean.indexOf('camo') !== -1) {
            return 'https://cfx-nui-ox_inventory/web/images/digicamo_attachment.png';
        }

        return 'https://cfx-nui-ox_inventory/web/images/' + clean + '.png';
    }

    // =====================================================
    //  Alternância de Abas (Fabricação x Upgrades)
    // =====================================================

    function switchTab(tab) {
        currentTab = tab;
        closePopover();

        if (tab === 'crafting') {
            activeWeaponPropKey = null;
            if (tabCrafting) tabCrafting.classList.add('active');
            if (tabUpgrades) tabUpgrades.classList.remove('active');
            if (viewCrafting) {
                viewCrafting.style.display = 'flex';
                viewCrafting.classList.add('active');
            }
            if (viewUpgrades) {
                viewUpgrades.style.display = 'none';
                viewUpgrades.classList.remove('active');
            }
            if (searchInput) {
                searchInput.placeholder = 'Buscar receitas...';
                searchInput.value = '';
            }
            applySearchFilter('');
            fetch('https://' + getResourceName() + '/clearUpgradeWeapon', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify({})
            }).catch(function () {});
        } else if (tab === 'upgrades') {
            if (tabUpgrades) tabUpgrades.classList.add('active');
            if (tabCrafting) tabCrafting.classList.remove('active');
            if (viewUpgrades) {
                viewUpgrades.style.display = 'flex';
                viewUpgrades.classList.add('active');
            }
            if (viewCrafting) {
                viewCrafting.style.display = 'none';
                viewCrafting.classList.remove('active');
            }
            if (searchInput) {
                searchInput.placeholder = 'Buscar armas...';
                searchInput.value = '';
            }
            loadUpgradeData();
        }
    }

    if (tabCrafting) {
        tabCrafting.addEventListener('click', function () { switchTab('crafting'); });
    }
    if (tabUpgrades) {
        tabUpgrades.addEventListener('click', function () { switchTab('upgrades'); });
    }

    // =====================================================
    //  Carregamento e Renderização de Armas (Upgrades)
    // =====================================================

    function loadUpgradeData() {
        fetch('https://' + getResourceName() + '/getUpgradeData', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify({})
        })
        .then(function (res) { return res.json(); })
        .then(function (data) {
            weapons = data.weapons || [];
            inventoryAttachments = data.attachments || [];
            availableTints = data.tints || TINTS_LIST;
            filteredWeapons = [].concat(weapons);
            renderWeaponsList();
            renderInventoryComponentsList();

            if (selectedWeapon) {
                var found = null;
                for (var i = 0; i < weapons.length; i++) {
                    if (weapons[i].slot === selectedWeapon.slot) {
                        found = weapons[i];
                        break;
                    }
                }
                if (found) {
                    // Os dados visuais mudaram, mas a arma fisica ja foi
                    // atualizada pelo cliente Lua. Nao recriar o prop aqui.
                    selectWeapon(found);
                    return;
                }
            }
            if (weapons.length > 0) {
                selectWeapon(weapons[0]);
            } else {
                showEmptyWeaponDetail();
            }
        })
        .catch(function () {
            weapons = [];
            filteredWeapons = [];
            renderWeaponsList();
            renderInventoryComponentsList();
            showEmptyWeaponDetail();
        });
    }

    function renderWeaponsList() {
        if (!weaponsList) return;
        weaponsList.innerHTML = '';
        if (weaponsCount) weaponsCount.textContent = filteredWeapons.length;

        if (filteredWeapons.length === 0) {
            weaponsList.innerHTML = '<div class="empty-list-msg">Nenhuma arma encontrada no inventário</div>';
            return;
        }

        filteredWeapons.forEach(function (weapon) {
            var isSelected = selectedWeapon && selectedWeapon.slot === weapon.slot;
            var card = document.createElement('div');
            card.className = 'recipe-card' + (isSelected ? ' active' : '');

            var imgWrapper = document.createElement('div');
            imgWrapper.className = 'recipe-card-img';
            var img = document.createElement('img');
            img.alt = weapon.label || weapon.name;
            var cleanName = (weapon.name || '').replace(/^WEAPON_/i, '').toLowerCase();
            img.dataset.itemName = weapon.name || '';
            img.src = normalizeImageUrl(weapon.image || (baseImagePath + cleanName + '.png'));
            img.onerror = function () { handleImageError(this); };
            imgWrapper.appendChild(img);

            var info = document.createElement('div');
            info.className = 'recipe-card-info';
            var title = document.createElement('div');
            title.className = 'recipe-card-title';
            title.textContent = weapon.label || weapon.name;

            var meta = document.createElement('div');
            meta.className = 'recipe-card-meta';

            var serialSpan = document.createElement('span');
            serialSpan.className = 'meta-time';
            serialSpan.textContent = '#' + (weapon.serial || '0000');

            var compCount = (weapon.components && weapon.components.length) ? weapon.components.length : 0;
            var compBadge = document.createElement('span');
            compBadge.className = 'meta-xp';
            compBadge.textContent = compCount + ' comp.';

            meta.appendChild(serialSpan);
            meta.appendChild(compBadge);
            info.appendChild(title);
            info.appendChild(meta);

            card.appendChild(imgWrapper);
            card.appendChild(info);

            card.addEventListener('click', function () {
                selectWeapon(weapon);
            });

            weaponsList.appendChild(card);
        });
    }

    function getWeaponPropKey(weapon) {
        if (!weapon) return null;
        return [weapon.slot, weapon.name || '', weapon.serial || ''].join('|');
    }

    function selectWeapon(weapon) {
        var nextPropKey = getWeaponPropKey(weapon);
        selectedWeapon = weapon;
        var inspectTarget = document.getElementById('weapon-center-target');
        if (inspectTarget) inspectTarget.classList.remove('expanded');
        renderWeaponsList();

        if (weaponDetailEmpty) weaponDetailEmpty.style.display = 'none';
        if (weaponDetailContent) weaponDetailContent.style.display = 'flex';

        if (benchmatWeaponTitle) benchmatWeaponTitle.textContent = (weapon.label || weapon.name).toUpperCase();
        if (specSerial) specSerial.textContent = 'Serial: #' + (weapon.serial || '0000');
        if (specAmmo) specAmmo.textContent = 'Munição: ' + (weapon.ammo || 0);
        if (specDurability) specDurability.textContent = 'Durabilidade: ' + (weapon.durability || 100) + '%';

        renderInventoryComponentsList();
        renderWeaponSlots(weapon);

        // Selecionar novamente a mesma arma (inclusive apos recarregar o
        // inventario) nao deve destruir e criar outro WeaponObject.
        if (activeWeaponPropKey !== nextPropKey) {
            activeWeaponPropKey = nextPropKey;
            fetch('https://' + getResourceName() + '/selectUpgradeWeapon', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify({ weapon: weapon })
            }).catch(function () {
                if (activeWeaponPropKey === nextPropKey) activeWeaponPropKey = null;
            });
        }
    }

    function showEmptyWeaponDetail() {
        selectedWeapon = null;
        activeWeaponPropKey = null;
        var inspectTarget = document.getElementById('weapon-center-target');
        if (inspectTarget) inspectTarget.classList.remove('expanded');
        if (weaponDetailEmpty) weaponDetailEmpty.style.display = 'flex';
        if (weaponDetailContent) weaponDetailContent.style.display = 'none';
        fetch('https://' + getResourceName() + '/clearUpgradeWeapon', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify({})
        }).catch(function () {});
    }

    // =====================================================
    //  Renderização da Toolbar de Componentes do Inventário
    // =====================================================

    var dragState = {
        isDragging: false,
        componentName: null,
        slotType: null,
        ghostEl: null
    };

    function renderInventoryComponentsList() {
        if (!invComponentsList) return;
        invComponentsList.innerHTML = '';

        var totalCount = 0;
        if (inventoryAttachments && inventoryAttachments.length > 0) {
            inventoryAttachments.forEach(function (it) {
                totalCount += (it.count || 1);
            });
        }

        if (invComponentsCount) {
            invComponentsCount.textContent = totalCount + (totalCount === 1 ? ' item' : ' itens');
        }

        if (!inventoryAttachments || inventoryAttachments.length === 0) {
            invComponentsList.innerHTML = '<span class="inv-comp-empty-msg">Nenhum componente no inventário</span>';
            return;
        }

        inventoryAttachments.forEach(function (it) {
            var tile = document.createElement('div');
            tile.className = 'inv-comp-tile';
            var qty = it.count || 1;
            var compatible = isAttachmentCompatible(it, selectedWeapon);
            tile.title = (it.label || it.name) + ' (' + qty + 'x)\n'
                + (compatible ? 'Clique ou arraste até a bancada para acoplar' : 'Incompatível com esta arma');
            tile.setAttribute('draggable', compatible ? 'true' : 'false');
            tile.dataset.compName = it.name;
            if (!compatible) tile.classList.add('incompatible');

            var img = document.createElement('img');
            img.className = 'inv-comp-tile-img';
            img.alt = it.label || it.name;
            img.dataset.itemName = it.name;
            img.src = normalizeImageUrl(it.image || resolveAttachmentImage(it.name));
            img.onerror = function () { handleImageError(this); };
            tile.appendChild(img);

            if (qty > 1) {
                var badge = document.createElement('span');
                badge.className = 'inv-comp-badge';
                badge.textContent = 'x' + qty;
                tile.appendChild(badge);
            }

            // HTML5 Drag
            tile.addEventListener('dragstart', function (e) {
                if (!compatible) {
                    e.preventDefault();
                    return;
                }
                dragState.isDragging = true;
                dragState.componentName = it.name;
                dragState.slotType = getComponentSlot(it.name);
                tile.classList.add('dragging');
                if (e.dataTransfer) {
                    e.dataTransfer.setData('text/plain', it.name);
                    e.dataTransfer.effectAllowed = 'copyMove';
                }
            });

            tile.addEventListener('dragend', function () {
                dragState.isDragging = false;
                dragState.componentName = null;
                dragState.slotType = null;
                tile.classList.remove('dragging');
                document.querySelectorAll('.callout-slot-box').forEach(function (b) {
                    b.classList.remove('drag-over');
                });
            });

            // Pointer / Mouse Drag para compatibilidade com CEF / DUI
            tile.addEventListener('mousedown', function (e) {
                if (e.button !== 0 || !compatible) return;
                var startX = e.clientX;
                var startY = e.clientY;
                var hasStarted = false;
                var compName = it.name;

                function onMove(mEvt) {
                    var dx = mEvt.clientX - startX;
                    var dy = mEvt.clientY - startY;
                    if (!hasStarted && (Math.abs(dx) > 6 || Math.abs(dy) > 6)) {
                        hasStarted = true;
                        dragState.isDragging = true;
                        dragState.componentName = compName;
                        tile.classList.add('dragging');

                        var ghost = document.createElement('div');
                        ghost.className = 'drag-ghost-avatar';
                        var gImg = document.createElement('img');
                        gImg.dataset.itemName = compName;
                        gImg.src = normalizeImageUrl(it.image || resolveAttachmentImage(compName));
                        gImg.onerror = function () { handleImageError(this); };
                        ghost.appendChild(gImg);
                        document.body.appendChild(ghost);
                        dragState.ghostEl = ghost;
                    }

                    if (hasStarted && dragState.ghostEl) {
                        dragState.ghostEl.style.left = mEvt.clientX + 'px';
                        dragState.ghostEl.style.top = mEvt.clientY + 'px';

                        var elem = document.elementFromPoint(mEvt.clientX, mEvt.clientY);
                        document.querySelectorAll('.callout-slot-box').forEach(function (b) {
                            b.classList.remove('drag-over');
                        });
                        if (elem) {
                            var tBox = elem.closest('.callout-slot-box');
                            if (tBox) tBox.classList.add('drag-over');
                        }
                    }
                }

                function onUp(uEvt) {
                    window.removeEventListener('mousemove', onMove);
                    window.removeEventListener('mouseup', onUp);

                    if (hasStarted) {
                        tile.classList.remove('dragging');
                        if (dragState.ghostEl && dragState.ghostEl.parentNode) {
                            dragState.ghostEl.parentNode.removeChild(dragState.ghostEl);
                        }
                        dragState.ghostEl = null;

                        var elem = document.elementFromPoint(uEvt.clientX, uEvt.clientY);
                        document.querySelectorAll('.callout-slot-box').forEach(function (b) {
                            b.classList.remove('drag-over');
                        });

                        if (elem && selectedWeapon) {
                            var tBox = elem.closest('.callout-slot-box');
                            var bMat = elem.closest('.weapon-callout-stage');
                            if (tBox || bMat) {
                                handleInstallComponent(selectedWeapon, compName);
                            }
                        }

                        dragState.isDragging = false;
                        dragState.componentName = null;
                    }
                }

                window.addEventListener('mousemove', onMove);
                window.addEventListener('mouseup', onUp);
            });

            // Ao clicar no quadradinho do componente, acopla diretamente à arma selecionada
            tile.addEventListener('click', function () {
                if (dragState.isDragging) return;
                if (!selectedWeapon) return;
                if (!compatible) {
                    showUpgradeFeedback('Este componente não é compatível com a arma selecionada.', true);
                    return;
                }
                handleInstallComponent(selectedWeapon, it.name);
            });

            invComponentsList.appendChild(tile);
        });
    }

    // =====================================================
    //  Renderização dos 6 Callouts na Bancada 3D da Arma
    // =====================================================

    function renderWeaponSlots(weapon) {
        if (!weapon) return;

        var installedComponents = weapon.components || [];
        var tintIndex = Number(weapon.tint) || 0;

        SLOTS_CONFIG.forEach(function (slot) {
            var boxEl = document.getElementById('slot-box-' + slot.id);
            if (!boxEl) return;
            boxEl.innerHTML = '';

            // Suporte a Drop direto no slot
            boxEl.addEventListener('dragover', function (e) {
                e.preventDefault();
                if (e.dataTransfer) e.dataTransfer.dropEffect = 'copy';
                boxEl.classList.add('drag-over');
            });

            boxEl.addEventListener('dragleave', function () {
                boxEl.classList.remove('drag-over');
            });

            boxEl.addEventListener('drop', function (e) {
                e.preventDefault();
                boxEl.classList.remove('drag-over');
                var compName = (e.dataTransfer && e.dataTransfer.getData('text/plain')) || dragState.componentName;
                if (compName && selectedWeapon) {
                    handleInstallComponent(selectedWeapon, compName);
                }
            });

            var installedItem = null;

            if (slot.id === 'tint') {
                var installedSkin = null;
                for (var skinIndex = 0; skinIndex < installedComponents.length; skinIndex++) {
                    if (getComponentSlot(installedComponents[skinIndex]) === 'tint') {
                        installedSkin = installedComponents[skinIndex];
                        break;
                    }
                }
                if (installedSkin) {
                    installedItem = {
                        name: installedSkin,
                        label: formatComponentLabel(installedSkin),
                        isTint: false
                    };
                } else if (tintIndex > 0) {
                    var tintObj = null;
                    var tList = availableTints.length ? availableTints : TINTS_LIST;
                    for (var t = 0; t < tList.length; t++) {
                        if (tList[t].id === tintIndex) {
                            tintObj = tList[t];
                            break;
                        }
                    }
                    installedItem = {
                        name: 'tint_' + tintIndex,
                        label: (tintObj ? tintObj.label : 'Pintura ' + tintIndex),
                        color: (tintObj ? tintObj.color : '#38bdf8'),
                        isTint: true,
                        tintIndex: tintIndex
                    };
                }
            } else {
                for (var i = 0; i < installedComponents.length; i++) {
                    var comp = installedComponents[i];
                    if (getComponentSlot(comp) === slot.id) {
                        installedItem = {
                            name: comp,
                            label: formatComponentLabel(comp),
                            isTint: false
                        };
                        break;
                    }
                }
            }

            var calloutNode = document.getElementById('callout-' + slot.id);
            var nodeLabel = calloutNode ? calloutNode.querySelector('.callout-label') : null;

            if (installedItem) {
                boxEl.classList.add('installed');
                boxEl.classList.remove('empty');
                if (calloutNode) calloutNode.classList.add('is-installed');
                boxEl.title = installedItem.label + ' (Instalado)\nClique para remover imediatamente';

                if (installedItem.isTint) {
                    var colorDot = document.createElement('div');
                    colorDot.className = 'comp-color-preview';
                    colorDot.style.backgroundColor = installedItem.color || '#38bdf8';
                    colorDot.style.width = '32px';
                    colorDot.style.height = '32px';
                    colorDot.style.borderRadius = '50%';
                    colorDot.style.border = '2px solid rgba(255,255,255,0.85)';
                    colorDot.style.boxShadow = '0 0 12px rgba(56,189,248,0.6)';
                    boxEl.appendChild(colorDot);
                } else {
                    var img = document.createElement('img');
                    img.className = 'slot-icon-img';
                    img.alt = installedItem.label;
                    img.dataset.itemName = installedItem.name;
                    img.src = resolveAttachmentImage(installedItem.name);
                    img.onerror = function () { handleImageError(this); };
                    boxEl.appendChild(img);
                }

                // Botão visual ✕ de remoção rápida
                var btnRemove = document.createElement('button');
                btnRemove.className = 'btn-remove-slot';
                btnRemove.title = 'Desinstalar componente';
                btnRemove.textContent = '✕';
                boxEl.appendChild(btnRemove);

                if (nodeLabel) {
                    nodeLabel.innerHTML = (slot.shortLabel || slot.label).toUpperCase() + ' <span class="slot-tag-installed">(Instalado)</span>';
                }

                // Clique direto em qualquer parte do slot instalado remove imediatamente o componente!
                boxEl.onclick = function (e) {
                    if (e) e.stopPropagation();
                    if (installedItem.isTint) {
                        handleSetTint(weapon, 0);
                    } else {
                        handleRemoveComponent(weapon, installedItem.name);
                    }
                };
            } else {
                boxEl.classList.remove('installed');
                boxEl.classList.add('empty');
                if (calloutNode) calloutNode.classList.remove('is-installed');
                boxEl.title = slot.label + ' (Vazio)\nClique para escolher ou arraste o item aqui';

                // Slot vazio: exibe um sutil ícone de "+" limpo
                var emptyDiv = document.createElement('div');
                emptyDiv.className = 'slot-empty-plus';
                emptyDiv.innerHTML = '<svg viewBox="0 0 24 24" width="20" height="20" stroke="currentColor" stroke-width="2.2" fill="none"><line x1="12" y1="5" x2="12" y2="19"></line><line x1="5" y1="12" x2="19" y2="12"></line></svg>';
                boxEl.appendChild(emptyDiv);

                if (nodeLabel) {
                    nodeLabel.innerHTML = (slot.shortLabel || slot.label).toUpperCase() + ' <span class="slot-tag-empty">(Vazio)</span>';
                }

                boxEl.onclick = function () {
                    openPopoverForSlot(slot, boxEl);
                };
            }
        });
    }

    // =====================================================
    //  Popover de Seleção de Acessórios & Pinturas
    // =====================================================

    function openPopoverForSlot(slot, slotElement) {
        if (!compPickerPopover || !selectedWeapon) return;
        activePopoverSlot = slot;

        if (popoverTitle) popoverTitle.textContent = slot.label;
        if (popoverItemsList) popoverItemsList.innerHTML = '';

        if (slot.id === 'tint') {
            var tints = (availableTints && availableTints.length) ? availableTints : TINTS_LIST;
            tints.forEach(function (tint) {
                var isCur = Number(selectedWeapon.tint) === tint.id;
                var itemEl = document.createElement('div');
                itemEl.className = 'popover-item' + (isCur ? ' active' : '');

                var leftDiv = document.createElement('div');
                leftDiv.className = 'popover-item-left';

                var colorBox = document.createElement('span');
                colorBox.className = 'popover-tint-circle';
                colorBox.style.backgroundColor = tint.color;
                leftDiv.appendChild(colorBox);

                var name = document.createElement('span');
                name.className = 'popover-item-label';
                name.textContent = tint.label;
                leftDiv.appendChild(name);

                itemEl.appendChild(leftDiv);

                var btn = document.createElement('button');
                btn.className = 'btn-popover-equip';
                btn.textContent = isCur ? 'Aplicada' : 'Aplicar';
                btn.disabled = isCur;
                btn.addEventListener('click', function (e) {
                    e.stopPropagation();
                    handleSetTint(selectedWeapon, tint.id);
                });
                itemEl.appendChild(btn);

                popoverItemsList.appendChild(itemEl);
            });
        } else {
            var matching = inventoryAttachments.filter(function (it) {
                return getComponentSlot(it.name) === slot.id && isAttachmentCompatible(it, selectedWeapon);
            });

            if (matching.length === 0) {
                popoverItemsList.innerHTML = '<div class="popover-empty">Nenhum acessório compatível no seu inventário.</div>';
            } else {
                matching.forEach(function (it) {
                    var itemEl = document.createElement('div');
                    itemEl.className = 'popover-item';

                    var leftDiv = document.createElement('div');
                    leftDiv.className = 'popover-item-left';

                    var img = document.createElement('img');
                    img.className = 'popover-item-img';
                    img.dataset.itemName = it.name;
                    img.src = normalizeImageUrl(it.image || resolveAttachmentImage(it.name));
                    img.onerror = function () { handleImageError(this); };
                    leftDiv.appendChild(img);

                    var nameWrapper = document.createElement('div');
                    nameWrapper.className = 'popover-item-info';
                    var nameSpan = document.createElement('span');
                    nameSpan.className = 'popover-item-label';
                    nameSpan.textContent = it.label || it.name;
                    var qtySpan = document.createElement('span');
                    qtySpan.className = 'popover-item-count';
                    qtySpan.textContent = 'Qtd: ' + (it.count || 1);
                    nameWrapper.appendChild(nameSpan);
                    nameWrapper.appendChild(qtySpan);
                    leftDiv.appendChild(nameWrapper);

                    itemEl.appendChild(leftDiv);

                    var btnEquip = document.createElement('button');
                    btnEquip.className = 'btn-popover-equip';
                    btnEquip.textContent = 'Acoplar';
                    btnEquip.addEventListener('click', function (e) {
                        e.stopPropagation();
                        handleInstallComponent(selectedWeapon, it.name);
                    });
                    itemEl.appendChild(btnEquip);

                    popoverItemsList.appendChild(itemEl);
                });
            }
        }

        compPickerPopover.style.display = 'block';
    }

    function closePopover() {
        if (compPickerPopover) compPickerPopover.style.display = 'none';
        activePopoverSlot = null;
    }

    if (btnPopoverClose) {
        btnPopoverClose.addEventListener('click', closePopover);
    }

    function findAttachment(componentName) {
        for (var i = 0; i < inventoryAttachments.length; i++) {
            if (String(inventoryAttachments[i].name).toLowerCase() === String(componentName).toLowerCase()) {
                return inventoryAttachments[i];
            }
        }
        return null;
    }

    function isAttachmentCompatible(attachment, weapon) {
        if (!attachment || !weapon) return false;
        var map = attachment.compatibleWeapons;
        if (!map || typeof map !== 'object') return true;
        return map[String(weapon.slot)] === true;
    }

    function showUpgradeFeedback(message, isError) {
        if (!message) return;
        var toast = document.createElement('div');
        toast.className = 'upgrade-toast' + (isError ? ' error' : ' success');
        toast.textContent = message;
        document.body.appendChild(toast);
        window.setTimeout(function () {
            if (toast.parentNode) toast.parentNode.removeChild(toast);
        }, 2800);
    }

    function handleInstallComponent(weapon, componentItem) {
        if (!weapon || !componentItem) return;
        var attachment = findAttachment(componentItem);
        if (attachment && !isAttachmentCompatible(attachment, weapon)) {
            showUpgradeFeedback('Este componente não é compatível com a arma selecionada.', true);
            return;
        }
        fetch('https://' + getResourceName() + '/installWeaponComponent', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify({
                weaponSlot: weapon.slot,
                weaponName: weapon.name,
                componentItem: componentItem
            })
        })
        .then(function (res) { return res.json(); })
        .then(function (res) {
            closePopover();
            if (res.ok) {
                var inspectTarget = document.getElementById('weapon-center-target');
                if (inspectTarget) inspectTarget.classList.remove('expanded');
                loadUpgradeData();
            } else {
                showUpgradeFeedback(res.message || 'Não foi possível instalar o componente.', true);
            }
        })
        .catch(function () { showUpgradeFeedback('Falha ao comunicar com a bancada.', true); });
    }

    function handleRemoveComponent(weapon, componentName) {
        if (!weapon || !componentName) return;
        fetch('https://' + getResourceName() + '/removeWeaponComponent', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify({
                weaponSlot: weapon.slot,
                componentName: componentName
            })
        })
        .then(function (res) { return res.json(); })
        .then(function (res) {
            if (res.ok) {
                var inspectTarget = document.getElementById('weapon-center-target');
                if (inspectTarget) inspectTarget.classList.remove('expanded');
                loadUpgradeData();
            } else {
                showUpgradeFeedback(res.message || 'Não foi possível remover o componente.', true);
            }
        })
        .catch(function () {});
    }

    function handleSetTint(weapon, tintIndex) {
        if (!weapon) return;
        fetch('https://' + getResourceName() + '/setWeaponTint', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify({
                weaponSlot: weapon.slot,
                tintIndex: tintIndex
            })
        })
        .then(function (res) { return res.json(); })
        .then(function (res) {
            closePopover();
            if (res.ok) {
                weapon.tint = tintIndex;
                var inspectTarget = document.getElementById('weapon-center-target');
                if (inspectTarget) inspectTarget.classList.remove('expanded');
                renderWeaponSlots(weapon);
                renderWeaponsList();
            }
        })
        .catch(function () {});
    }

    // =====================================================
    //  Filtro de Busca Inteligente
    // =====================================================

    function applySearchFilter(query) {
        query = (query || '').toLowerCase().trim();
        if (currentTab === 'upgrades') {
            if (!query) {
                filteredWeapons = [].concat(weapons);
            } else {
                filteredWeapons = weapons.filter(function (w) {
                    var name = (w.name || '').toLowerCase();
                    var label = (w.label || '').toLowerCase();
                    var serial = (w.serial || '').toLowerCase();
                    return name.indexOf(query) !== -1 || label.indexOf(query) !== -1 || serial.indexOf(query) !== -1;
                });
            }
            renderWeaponsList();
        } else {
            if (!query) {
                filteredRecipes = [].concat(recipes);
            } else {
                filteredRecipes = recipes.filter(function (recipe) {
                    var name = (recipe.item || '').toLowerCase();
                    var label = (recipe.item_label || '').toLowerCase();
                    return name.indexOf(query) !== -1 || label.indexOf(query) !== -1;
                });
            }
            renderRecipesList();
        }
    }

    if (searchInput) {
        searchInput.addEventListener('input', function (e) {
            applySearchFilter(e.target.value);
        });

        function handleSearchFocus(e) {
            if (e) {
                if (e.preventDefault) e.preventDefault();
                if (e.stopPropagation) e.stopPropagation();
            }
            try {
                fetch('https://' + getResourceName() + '/openSearchInput', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                    body: JSON.stringify({ mode: currentTab })
                }).catch(function () {});
            } catch (err) {}
        }
        searchInput.addEventListener('mousedown', handleSearchFocus);
        searchInput.addEventListener('click', handleSearchFocus);
    }

    function getResourceName() {
        return (window.GetParentResourceName ? window.GetParentResourceName() : 'forge-crafting');
    }

    // Fechar Interface
    function closeUI() {
        closePopover();
        activeWeaponPropKey = null;
        if (appContainer) {
            appContainer.style.display = 'none';
            appContainer.classList.remove('active');
        }
        try {
            fetch('https://' + getResourceName() + '/close', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify({})
            }).catch(function () {});
        } catch (e) {}
    }

    function handleCloseBtn(e) {
        if (e) {
            if (e.preventDefault) e.preventDefault();
            if (e.stopPropagation) e.stopPropagation();
        }
        closeUI();
    }
    if (btnClose) {
        btnClose.addEventListener('mousedown', handleCloseBtn);
        btnClose.addEventListener('click', handleCloseBtn);
    }

    // Tecla ESC para fechar
    window.addEventListener('keydown', function (e) {
        if (e.key === 'Escape') {
            if (compPickerPopover && compPickerPopover.style.display !== 'none') {
                closePopover();
                return;
            }
            closeUI();
        }
    });

    // Ação de Fabricar
    function handleCraftBtn(e) {
        if (e) {
            if (e.preventDefault) e.preventDefault();
            if (e.stopPropagation) e.stopPropagation();
        }
        if (!selectedRecipe || (btnCraft && btnCraft.disabled)) return;

        fetch('https://' + getResourceName() + '/craft', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify({
                craft_id: benchData ? benchData.id : null,
                craft_item: selectedRecipe.item,
                item_label: selectedRecipe.item_label,
                time: selectedRecipe.time,
                amount: selectedRecipe.amount,
                recipe: selectedRecipe.recipe,
                coords: benchData ? benchData.coords : null,
                anim: selectedRecipe.anim,
                model: selectedRecipe.model,
                level: selectedRecipe.level
            })
        }).catch(function () {});
    }

    if (btnCraft) {
        btnCraft.addEventListener('mousedown', handleCraftBtn);
        btnCraft.addEventListener('click', handleCraftBtn);
    }

    var weaponStageEl = document.querySelector('.weapon-callout-stage');
    if (weaponStageEl) {
        weaponStageEl.addEventListener('dragover', function (e) {
            e.preventDefault();
            if (e.dataTransfer) e.dataTransfer.dropEffect = 'copy';
        });
        weaponStageEl.addEventListener('drop', function (e) {
            e.preventDefault();
            var compName = (e.dataTransfer && e.dataTransfer.getData('text/plain')) || dragState.componentName;
            if (compName && selectedWeapon) {
                handleInstallComponent(selectedWeapon, compName);
            }
        });
    }

    var weaponInspectEl = document.getElementById('weapon-center-target');
    if (weaponInspectEl) {
        var toggleExplodedView = function () {
            if (!selectedWeapon || dragState.isDragging) return;
            fetch('https://' + getResourceName() + '/toggleExplodedView', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify({ weaponSlot: selectedWeapon.slot })
            })
            .then(function (res) { return res.json(); })
            .then(function (res) {
                if (res.ok) {
                    weaponInspectEl.classList.toggle('expanded', res.expanded === true);
                    weaponInspectEl.title = res.expanded
                        ? 'Clique para remontar os componentes'
                        : 'Clique na arma para expandir os componentes';
                }
            })
            .catch(function () {});
        };
        weaponInspectEl.addEventListener('click', toggleExplodedView);
        weaponInspectEl.addEventListener('keydown', function (e) {
            if (e.key === 'Enter' || e.key === ' ') {
                e.preventDefault();
                toggleExplodedView();
            }
        });
    }

    // Aplica personalização dinâmica de tema via CSS Custom Properties
    function applyTheme(theme) {
        if (!theme || typeof theme !== 'object') return;
        var root = document.documentElement;
        for (var key in theme) {
            if (theme.hasOwnProperty(key)) {
                var val = theme[key];
                if (val !== undefined && val !== null) {
                    var cssVar = '--' + key.replace(/_/g, '-');
                    if (key.indexOf('_image') !== -1) {
                        if (!val || val === '' || val === 'none') {
                            val = 'none';
                        } else if (!val.startsWith('url(')) {
                            val = 'url("' + val + '")';
                        }
                    }
                    root.style.setProperty(cssVar, val);
                }
            }
        }
    }

    // Listener de Mensagens da NUI/DUI do FiveM
    window.addEventListener('message', function (event) {
        var data = event.data;
        if (!data) return;

        if (data.theme) {
            applyTheme(data.theme);
        }

        if (data.action === 'setTheme') {
            if (data.theme) applyTheme(data.theme);
        } else if (data.action === 'standby') {
            activeWeaponPropKey = null;
            if (appContainer) {
                appContainer.style.display = 'none';
                appContainer.classList.remove('active');
            }
            if (standbyApp) {
                standbyApp.style.display = 'flex';
                standbyApp.classList.add('active');
            }
            if (standbyLogo && data.logo) {
                standbyLogo.src = data.logo;
            }
            if (standbyTitle) {
                standbyTitle.textContent = data.title || (data.bench && data.bench.name) || 'FORGE CRAFTING';
            }
            if (standbySubtitle) {
                standbySubtitle.textContent = data.subtitle || 'BANCADA DE TRABALHO';
            }
        } else if (data.action === 'open' || data.action === 'sync') {
            if (standbyApp) {
                standbyApp.style.display = 'none';
                standbyApp.classList.remove('active');
            }

            benchData = data.bench || {};
            recipes = data.items || [];
            playerLevel = Number(data.playerLevel) || 0;
            baseImagePath = data.imagePath || baseImagePath;

            if (benchTitle) benchTitle.textContent = benchData.name || 'Bancada de Trabalho';
            if (playerLevelVal) playerLevelVal.textContent = formatLevel(playerLevel);

            if (searchInput) searchInput.value = '';
            filteredRecipes = [].concat(recipes);

            if (appContainer) {
                appContainer.style.display = 'flex';
                appContainer.classList.add('active');
            }

            switchTab('crafting');
            renderRecipesList();
        } else if (data.action === 'search' || data.action === 'setSearch') {
            var query = data.query || data.text || '';
            if (searchInput) searchInput.value = query;
            applySearchFilter(query);
        } else if (data.action === 'updatePlayerLevel') {
            playerLevel = Number(data.playerLevel) || 1;
            if (playerLevelVal) playerLevelVal.textContent = formatLevel(playerLevel);
            renderRecipesList();
            if (selectedRecipe) renderRecipeDetail(selectedRecipe);
        } else if (data.action === 'openUpgradeTab') {
            switchTab('upgrades');
            if (data.weapons && data.weapons.length > 0) {
                weapons = data.weapons;
                inventoryAttachments = data.attachments || [];
                availableTints = data.tints || TINTS_LIST;
                filteredWeapons = [].concat(weapons);
                renderWeaponsList();
                renderInventoryComponentsList();
                selectWeapon(weapons[0]);
            }
        } else if (data.action === 'close') {
            closePopover();
            activeWeaponPropKey = null;
            if (appContainer) {
                appContainer.style.display = 'none';
                appContainer.classList.remove('active');
            }
            if (standbyApp) {
                standbyApp.style.display = 'none';
                standbyApp.classList.remove('active');
            }
        }
    });

})();
