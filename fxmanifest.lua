fx_version 'cerulean'
game 'gta5'

name 'pulse_911'
description 'PulseMDT - Civilian 911 / 311 calls'
version '0.1.0'
author 'PulseMDT'
url 'https://pulsemdt.com'

dependency 'pulsemdt'

shared_scripts {
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

ui_page 'nui/index.html'

files {
    'nui/index.html',
    'nui/style.css',
    'nui/app.js',
}
