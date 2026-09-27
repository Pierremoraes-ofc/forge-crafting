fx_version 'cerulean'
game 'gta5'
description 'crafting_system'
author 'QT Store'
lua54 'yes'

shared_scripts {
    'shared/*.lua',
    '@ox_lib/init.lua',
    'bridge/framework.lua',
}

client_scripts {
    'bridge/client/*.lua',
    'cl_utils.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/server/*.lua',
    'sv_utils.lua',
}

dependencies {
    'oxmysql',
    'ox_lib',
}
