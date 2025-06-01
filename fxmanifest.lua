fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Muhaddil'
description 'Simple robbery disponibility script for FiveM'
version 'v1.0.122'

client_script 'client/*'
server_script {
    '@oxmysql/lib/MySQL.lua',
    'server/*'
}

shared_script {
    '@ox_lib/init.lua',
    'config.lua',
}

files {
    'locales/*.json'
}

escrow_ignore {
    'locales/*.json',
    'config.lua',
}