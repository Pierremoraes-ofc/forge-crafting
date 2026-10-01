/* =====================================================
   Forge Crafting - Interface NUI Moderna de Bancada
   Lógica Vanilla JS para FiveM CEF
   ===================================================== */

const FALLBACK_SVG = `data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" width="36" height="36" viewBox="0 0 24 24" fill="none" stroke="%2364748b" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"></path><polyline points="3.27 6.96 12 12.01 20.73 6.96"></polyline><line x1="12" y1="22.08" x2="12" y2="12"></line></svg>`;

let benchData = null;
let recipes = [];
let filteredRecipes = [];
let selectedRecipe = null;
let playerLevel = 0;
let baseImagePath = 'nui://ox_inventory/web/images/';

// Elementos DOM
const appContainer = document.getElementById('crafting-app');
const benchTitle = document.getElementById('bench-title');
const playerLevelVal = document.getElementById('player-level-val');
const searchInput = document.getElementById('search-input');
const btnClose = document.getElementById('btn-close');
const recipesList = document.getElementById('recipes-list');
const recipesCount = document.getElementById('recipes-count');

const detailEmpty = document.getElementById('recipe-detail-empty');
const detailContent = document.getElementById('recipe-detail-content');
const detailImage = document.getElementById('detail-image');
const detailAmount = document.getElementById('detail-amount');
const detailTitle = document.getElementById('detail-title');
const detailTime = document.getElementById('detail-time');
const detailLevelReq = document.getElementById('detail-level-req');
const detailLevelMeta = document.getElementById('detail-level-meta');
const ingredientsGrid = document.getElementById('ingredients-grid');
const materialsStatus = document.getElementById('materials-status');
const statusWarning = document.getElementById('status-warning');
const warningMessage = document.getElementById('warning-message');
const btnCraft = document.getElementById('btn-craft');

// Helper para tratar erro de imagem
function handleImageError(img) {
    img.onerror = null;
    img.src = FALLBACK_SVG;
}

// Constrói URL da imagem do item
function getItemImageUrl(itemName) {
    if (!itemName) return FALLBACK_SVG;
    let path = baseImagePath;
    if (!path.endsWith('/')) path += '/';
    return `${path}${itemName}.png`;
}

// Formatação do nível
function formatLevel(lvl) {
    if (typeof lvl === 'string' && lvl.toLowerCase() === 'maestria') {
        return 'Maestria';
    }
    const num = Number(lvl) || 0;
    if (num >= 999999) return 'Maestria';
    return `Nível ${num}`;
}

// Avalia a disponibilidade de uma receita
function checkRecipeAvailability(recipe) {
    const levelNeeded = Number(recipe.level) || 0;
    const meetsLevel = playerLevel >= levelNeeded;

    let hasAllIngredients = true;
    for (const ing of (recipe.recipe || [])) {
        const required = Number(ing.amount) || 1;
        const owned = Number(ing.currentAmount || ing.count || ing.owned || 0);
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
    recipesList.innerHTML = '';
    recipesCount.textContent = filteredRecipes.length;

    if (filteredRecipes.length === 0) {
        recipesList.innerHTML = `
            <div style="padding: 24px; text-align: center; color: #64748b; font-size: 0.85rem;">
                Nenhuma receita encontrada.
            </div>
        `;
        showEmptyDetail();
        return;
    }

    filteredRecipes.forEach(recipe => {
        const availability = checkRecipeAvailability(recipe);
        const card = document.createElement('div');
        card.className = `recipe-card ${selectedRecipe && selectedRecipe.item === recipe.item ? 'active' : ''}`;

        let statusClass = 'available';
        let statusText = 'Disponível';

        if (!availability.meetsLevel) {
            statusClass = 'locked';
            statusText = `Nível ${availability.levelNeeded}`;
        } else if (!availability.hasAllIngredients) {
            statusClass = 'missing';
            statusText = 'Faltam Itens';
        }

        const imgUrl = getItemImageUrl(recipe.item);

        card.innerHTML = `
            <div class="recipe-card-img">
                <img src="${imgUrl}" alt="${recipe.item_label || recipe.item}" onerror="handleImageError(this)">
            </div>
            <div class="recipe-card-info">
                <div class="recipe-card-title">${recipe.item_label || recipe.item}</div>
                <div class="recipe-card-meta">
                    <span class="status-badge ${statusClass}">${statusText}</span>
                    <span>${recipe.time || 0}s</span>
                </div>
            </div>
        `;

        card.addEventListener('click', () => {
            selectRecipe(recipe);
        });

        recipesList.appendChild(card);
    });

    // Se houver receitas mas nenhuma selecionada (ou se a selecionada não estiver na lista filtrada), seleciona a primeira
    if (filteredRecipes.length > 0) {
        if (!selectedRecipe || !filteredRecipes.some(r => r.item === selectedRecipe.item)) {
            selectRecipe(filteredRecipes[0]);
        }
    } else {
        showEmptyDetail();
    }
}

// Seleciona e exibe detalhes de uma receita
function selectRecipe(recipe) {
    selectedRecipe = recipe;

    // Atualiza estado ativo nos cards
    const cards = recipesList.querySelectorAll('.recipe-card');
    cards.forEach((card, index) => {
        if (filteredRecipes[index] && filteredRecipes[index].item === recipe.item) {
            card.classList.add('active');
        } else {
            card.classList.remove('active');
        }
    });

    const availability = checkRecipeAvailability(recipe);

    detailEmpty.style.display = 'none';
    detailContent.style.display = 'flex';

    detailTitle.textContent = recipe.item_label || recipe.item;
    detailAmount.textContent = `x${recipe.amount || 1}`;
    detailTime.textContent = `${recipe.time || 0}s`;
    detailImage.src = getItemImageUrl(recipe.item);

    const levelNeeded = Number(recipe.level) || 0;
    if (levelNeeded > 0) {
        detailLevelMeta.style.display = 'flex';
        detailLevelReq.textContent = formatLevel(levelNeeded);
        if (playerLevel < levelNeeded) {
            detailLevelReq.style.color = '#f87171';
        } else {
            detailLevelReq.style.color = '#38bdf8';
        }
    } else {
        detailLevelMeta.style.display = 'none';
    }

    // Renderiza ingredientes
    ingredientsGrid.innerHTML = '';
    const ingredients = recipe.recipe || [];

    ingredients.forEach(ing => {
        const required = Number(ing.amount) || 1;
        const owned = Number(ing.currentAmount || ing.count || ing.owned || 0);
        const isSufficient = owned >= required;
        const ingImgUrl = getItemImageUrl(ing.item);

        const ingCard = document.createElement('div');
        ingCard.className = `ingredient-card ${isSufficient ? 'sufficient' : 'insufficient'}`;
        ingCard.innerHTML = `
            <div class="ingredient-img">
                <img src="${ingImgUrl}" alt="${ing.label || ing.item}" onerror="handleImageError(this)">
            </div>
            <div class="ingredient-info">
                <div class="ingredient-name">${ing.label || ing.item}</div>
                <div class="ingredient-count ${isSufficient ? 'sufficient' : 'insufficient'}">
                    ${owned} / ${required}
                </div>
            </div>
        `;
        ingredientsGrid.appendChild(ingCard);
    });

    // Atualiza botão de ação e avisos
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
            warningMessage.textContent = `Requer ${formatLevel(levelNeeded)}`;
        } else {
            materialsStatus.textContent = 'Materiais em falta';
            materialsStatus.style.color = '#f87171';
            warningMessage.textContent = 'Insumos insuficientes no inventário';
        }
    }
}

function showEmptyDetail() {
    selectedRecipe = null;
    detailEmpty.style.display = 'flex';
    detailContent.style.display = 'none';
}

// Filtro de busca
searchInput.addEventListener('input', (e) => {
    const term = (e.target.value || '').trim().toLowerCase();
    if (!term) {
        filteredRecipes = [...recipes];
    } else {
        filteredRecipes = recipes.filter(r => {
            const label = (r.item_label || '').toLowerCase();
            const name = (r.item || '').toLowerCase();
            return label.includes(term) || name.includes(term);
        });
    }
    renderRecipesList();
});

// Ação de fechar NUI
function closeUI() {
    appContainer.style.display = 'none';
    fetch(`https://${GetParentResourceName()}/close`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({})
    }).catch(() => {});
}

btnClose.addEventListener('click', closeUI);

// Tecla ESC para fechar
window.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        closeUI();
    }
});

// Ação de Fabricar
btnCraft.addEventListener('click', () => {
    if (!selectedRecipe || btnCraft.disabled) return;

    appContainer.style.display = 'none';

    fetch(`https://${GetParentResourceName()}/craft`, {
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
            objectid: benchData ? benchData.objectid : null,
            anim: selectedRecipe.anim,
            model: selectedRecipe.model,
            level: selectedRecipe.level
        })
    }).catch(() => {});
});

// Listener de Mensagens da NUI do FiveM
window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data) return;

    if (data.action === 'open') {
        benchData = data.bench || {};
        recipes = data.items || [];
        playerLevel = Number(data.playerLevel) || 0;
        baseImagePath = data.imagePath || baseImagePath;

        benchTitle.textContent = benchData.name || 'Bancada de Trabalho';
        playerLevelVal.textContent = formatLevel(playerLevel);

        searchInput.value = '';
        filteredRecipes = [...recipes];

        appContainer.style.display = 'flex';
        renderRecipesList();
    } else if (data.action === 'close') {
        appContainer.style.display = 'none';
    }
});
