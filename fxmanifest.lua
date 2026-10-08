fx_version 'cerulean'
game 'gta5'
description 'Sistema de Crafting Standalone Forge-Core'
author 'Forge-Core'
lua54 'yes'

dependency 'pr_bridge'

shared_scripts {
    '@pr_bridge/init.lua',
    'shared/config.lua',
    'shared/locales.lua',
    'shared/weapon_components.lua',
    'shared/receita_nova.lua',
    'shared/receita_tuning.lua',
}

client_scripts {
    'cl_dui.lua',
    'cl_benchtool.lua',
    'client.lua',
    'cl_utils.lua',
}

server_scripts {
    'sv_db.lua',
    'sv_utils.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/**',
    'html/js/**',
    'html/images/**',
    'data/standby_config.json',
}
