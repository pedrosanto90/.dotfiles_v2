#!/bin/bash

# Este script deve ser executado pelo utilizador normal, e não pelo root.

echo "--- Configuração Global do Git ---"
echo "Esta informação será usada para identificar as suas contribuições."

# Pede o nome de utilizador
read -r -p "Introduza o seu Nome Completo (ex: Pedro Almeida): " GIT_NAME
if [ -z "$GIT_NAME" ]; then
    echo "Nome não fornecido. A configuração do Git foi cancelada."
    exit 1
fi

# Pede o email
read -r -p "Introduza o seu Email (ex: pedro.almeida@exemplo.com): " GIT_EMAIL
if [ -z "$GIT_EMAIL" ]; then
    echo "Email não fornecido. A configuração do Git foi cancelada."
    exit 1
fi

# 1. Configurar o nome global
git config --global user.name "$GIT_NAME"
echo "✅ Nome de utilizador Git configurado: $GIT_NAME"

# 2. Configurar o email global
git config --global user.email "$GIT_EMAIL"
echo "✅ Email Git configurado: $GIT_EMAIL"

# 3. Opcional: Configurar o editor padrão (nvim)
# Assumimos que o Neovim será o editor padrão.
git config --global core.editor "nvim"
echo "✅ Editor Git configurado para Neovim."

echo "--- Configuração Git Concluída ---"
echo "Pode verificar as configurações globais com: git config --global -l"
