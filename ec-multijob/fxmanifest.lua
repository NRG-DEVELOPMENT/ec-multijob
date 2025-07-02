fx_version 'cerulean'
game 'gta5'

description 'EC-MultiJob - Advanced Multiple Jobs Management for QBCore and ESX'
author 'NRG-Development'
version '1.0.2'

ui_page 'html/index.html'

shared_scripts {
    '@qb-core/shared/locale.lua',
}

client_scripts {
    'client.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua',
}

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
}

lua54 'yes'
