# Setup Terraform + TFENV (PowerShell + WSL2)

> 🎯 **Objetivo**: 
> Este documento descreve a sequência correta de execução para instalar:

- WSL 2 + Ubuntu;
- TFENV;
- Terraform;
- Integração com PowerShell via wrappers.

## Sumário

[Visão Geral do Processo](#visão-geral-do-processo)
[1. Definir Usuário e Senha Linux](#1-definir-usuário-e-senha-linux)
[2. Executar Setup Principal](#2-executar-setup-principal)
[3. Criar Integração Windows (Wrappers)](#3-criar-integração-windows-wrappers)
[4. Fechar Terminal Administrador](#4-fechar-terminal-administrador)


## Visão Geral do Processo

O setup é dividido em 2 scripts:

1.  `01_tfenv_terraform.ps1` → Instala WSL + Ubuntu + TFENV + Terraform;
2.  `02_tfenv_wrappers.ps1` → Cria integração do Terraform com Windows.

Durante o processo será necessário:

- Definir usuário e senha Linux;
- Executar PowerShell como Administrador;
- Reiniciar o Windows (se solicitado);
- Executar novamente o primeiro script;
- Finalizar com o segundo script,

--------------------------------------------------------------

### 1. Definir Usuário e Senha Linux

Abra o PowerShell como Administrador e execute:
    
    $env:LINUX_USER="SeuNome"
    $env:LINUX_PASS="SenhaForte123"

Essas variáveis:

- São usadas como parâmetros pelo script;
- Criam automaticamente o usuário Linux dentro do Ubuntu;
- Permitem que o setup continue sem interação manual;
- Utilize uma senha forte.

--------------------------------------------------------------

### 2. Executar Setup Principal

Ainda no PowerShell como Administrador, execute:

    .\01_tfenv_terraform.ps1

Se o WSL ainda não estiver instalado, o Windows poderá iniciar a instalação do WSL e solicitar reinicialização.

Se isso acontecer:

1.  Reinicie o computador

2.  Abra novamente o PowerShell como Administrador

3.  Redefina as variáveis:

        $env:LINUX_USER="SeuNome"
        $env:LINUX_PASS="SenhaForte123"

4.  Execute novamente:

    `.\01_tfenv_terraform.ps1`

Em determinado momento o Ubuntu irá solicitar:

- Nome do usuário
- Senha

Informe exatamente o mesmo usuário e senha definidos anteriormente na declaração das variáveis.

--------------------------------------------------------------

### 3. Criar Integração Windows (Wrappers)

Após a conclusão completa do primeiro script, ainda no PowerShell como Administrador, execute:

    .\02_tfenv_wrappers.ps1

Este script:

-   Cria os wrappers `.cmd`
-   Adiciona no PATH do Windows
-   Permite usar `terraform` e `tfenv` direto no PowerShell

--------------------------------------------------------------

### 4. Fechar Terminal Administrador

Após concluir o segundo script:

1.  Feche completamente o PowerShell (Administrador)
2.  Abra um novo PowerShell normal

--------------------------------------------------------------

## Validação Final

No novo terminal, execute:

    tfenv --version
    terraform -version
    tfenv list-remote

Se tudo estiver correto, você verá:

-   Versão do tfenv
-   Versão ativa do Terraform
-   Lista de versões disponíveis para instalação
