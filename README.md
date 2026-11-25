## Versão nativa para Mac

O repositório agora inclui o esquema **PlantaoNaMaoMac**, com a barra lateral e o login Google inspirados no Kepleræ e o ícone original do Plantão na Mão. O esquema **PlantaoNaMao** continua sendo iPhone/iPad. As duas versões compartilham os dados e as regras de sincronização pelo Google.

Compilação automática: `.github/workflows/build-macos.yml`. Instruções, limitações da assinatura de widgets e validação em aparelhos: [MACOS_SETUP.md](MACOS_SETUP.md).

# Plantão na Mão · iOS 1.6

Agenda nativa para iPhone/iPad, com suporte a iOS 17 ou superior e Liquid Glass nativo no iOS 26.

## Novidades 1.6

- Novo ícone aprovado: calendário e relógio em vidro jade, preparado em PNG RGB opaco de 1024 × 1024 pixels, sem recorte ou mudança de composição.
- Cabeçalhos dos dias da semana e datas agora usam **a mesma grade de sete colunas**, eliminando a diferença de espaçamento entre o cabeçalho e o mês. O alinhamento é mantido nos modos normal e compacto e em meses com diferentes dias iniciais.
- Mantidos os lembretes locais, a sincronização por alterações e o nome da conta Google da versão 1.5, além do compartilhamento de widgets da 1.4.
- O teste de interface mede o centro horizontal de cada cabeçalho e da data correspondente em novembro/dezembro de 2026, fevereiro de 2027 e orientação horizontal.

## Recursos da versão 1.5 preservados

- Ajustes > Notificações: habilite lembretes e escolha **24 horas, 12 horas, 6 horas ou 30 minutos antes**. A preferência é local e fica desativada até o usuário habilitar. A permissão do iOS é solicitada nesse momento.
- Um lembrete local por plantão, com nome, local, datas/horários de início e fim, valor e observações. Funciona sem internet e com o app fechado; apresentação e som dependem da permissão, Foco e ajustes do sistema. Tocar abre a agenda no dia e o plantão correspondente.
- Editar, excluir ou receber mudanças pelo Google atualiza os lembretes. Trocar a antecedência reagenda os avisos. Desativar remove os avisos pendentes e entregues do app. Não são disparados avisos retroativos quando a antecedência já passou.
- Os próximos **64** avisos futuros ficam agendados, respeitando o limite do iOS. Ao abrir/retornar ao app ou alterar plantões, a fila é renovada. Ajustes informa quando há mais plantões além dessa fila. Não há polling, servidor, push remoto ou tarefa contínua em segundo plano.
- Sincronização Google **por alteração**, com agrupamento de edições por 2 segundos. Removido o timer de 30 segundos. O snapshot confirmado é persistido somente após upload bem-sucedido, e edições feitas durante a requisição continuam pendentes. Retornar ao app só sincroniza se houver pendências; falhas não iniciam repetição periódica. A primeira conexão/atualização sem confirmação anterior faz uma conciliação inicial.
- Para receber alterações feitas em outro aparelho sem editar neste, use **Sincronizar agora**. Não há busca periódica remota. Sem internet, as alterações ficam salvas e são reenviadas ao voltar ao app, editar novamente ou sincronizar manualmente.
- Conta Google mostra o **nome** do perfil, com “Conta Google conectada” caso ele não esteja disponível; o e-mail não é exibido. Vinculação de conta e tokens permanecem com as regras anteriores.

## Recursos da versão 1.4 preservados

- Alternativa ao App Group: o app publica uma projeção de datas e cores no Keychain, e o widget a lê pelos grupos autorizados pela assinatura. Isso atende assinadores que aplicam o mesmo grupo de Chaves ao app e à extensão, como pode ocorrer no KSign. Não depende de um Team ID fixo, de leitura do perfil de provisionamento, nem de APIs privadas.
- A projeção contém somente datas e cores do mês anterior, atual e seguinte, mais aparência e horário de atualização. Não envia nomes, valores, locais, anotações, IDs dos registros ou tokens Google às Chaves.
- O widget registra uma confirmação com a identificação dos dados lidos. Ajustes distingue gravação local, espera pela extensão e leitura confirmada. Uma gravação nas Chaves privadas do app sozinha não prova que o widget recebeu os dados.
- App Groups continua disponível. Ao ler, a extensão escolhe o snapshot mais recente e permite recuperar a configuração antiga.
- A permissão real depende da assinatura instalada: app e extensão precisam compartilhar pelo menos um grupo de Chaves ou App Group. O app não concede permissões que o perfil e a assinatura não autorizem.

## Recursos preservados

- Os três últimos plantões adicionados aparecem no topo do cadastro. Toque para copiar nome, horários, local, cor, valor e observações para um novo registro, com outro UUID. A data escolhida no calendário ou formulário é mantida; a previsão de pagamento é recalculada pelo padrão configurado, sem copiar o vencimento antigo.
- Deslize um plantão na agenda para editar ou excluir; a exclusão sempre pede confirmação.
- A agenda mostra o mês inteiro, do dia 1 ao último dia. Ao abrir o app, a lista começa no dia atual. Selecionar uma data rola a lista até ela, mas os dias anteriores continuam acessíveis. O calendário permanece fixo.
- Preço por plantão ou por hora. O cálculo por hora considera minutos e plantões noturnos, arredondando ao centavo. R$ 26,36/h das 07:00 às 19:00 = R$ 316,32.
- Valores aceitam vírgula ou ponto decimal e completam duas casas ao sair do campo. Um plantão salvo já entra na previsão financeira, sem chave manual de pagamento recebido.
- Financeiro por intervalo inclusivo de datas ou competências, ambos com dia, mês e ano, usando a data do plantão ou a previsão de pagamento. Sem previsão de pagamento, o registro continua disponível pelo filtro Plantão.
- INSS e imposto de renda opcionais, com percentuais manuais independentes sobre o bruto. Bruto, descontos e líquido são atualizados automaticamente. São estimativas: não aplicamos tabelas oficiais nem cálculo tributário progressivo.
- Painel mensal com plantões, horas, bruto, líquido estimado, gráfico dos últimos 12 meses e histórico mensal completo, incluindo meses sem movimento entre os registros.
- As 24 cores ficam no cadastro do plantão e nos aros; a aparência geral mantém a identidade jade, com opções clara, escura e automática.
- Widgets pequeno, médio e grande dedicados ao calendário, sem resumo ou mensagens no rodapé, com aros circulares nas cores dos plantões e aparência clara/escura. Dados são publicados antes de recarregar a timeline, com alternativa por Chaves, confirmação de leitura e atualização manual em Ajustes. A extensão já é compilada e incluída no IPA. Ver [configuração dos widgets](WIDGETS_SETUP.md).

## Instalação e widgets

Execute `xcodegen generate`, abra o projeto e configure sua equipe de assinatura Apple. O App Group padrão é `group.com.plantaonamao.shared`, que precisa ser registrado e habilitado na mesma equipe para app e extensão. Leia [WIDGETS_SETUP.md](WIDGETS_SETUP.md). Sem App Group, a versão 1.4 tenta o grupo de Chaves autorizado na assinatura. Se os grupos do app e da extensão forem isolados, a leitura não será confirmada e será necessário ajustar a assinatura.

O iOS controla quando widgets são redesenhados. Solicitamos atualizações ao salvar, excluir, sincronizar e mudar a aparência, além de atualizar o dia pela timeline. Não há garantia de atualização contínua com o app fechado.

## Google e dados anteriores

Mantemos a chave local original e o formato de valores em centavos. Campos novos são opcionais na leitura dos registros antigos. A sincronização passa a usar schema 2, lendo o schema 1 anterior; outros aparelhos precisam atualizar para 1.3 para sincronizar sem descartar os campos de cálculo por hora. O Client ID público do projeto original continua incluído. A API Drive e a autorização OAuth precisam estar configuradas; siga [GOOGLE_SYNC_SETUP.md](GOOGLE_SYNC_SETUP.md).

Os plantões e os novos campos de preço/data de criação são sincronizados. Preferências de aparência e percentuais de simulação financeira continuam locais. Registros de recebimento das versões anteriores são preservados internamente; a interface 1.3 passa a mostrar previsões, sem exigir marcação manual.

## PDF

Preservamos PDF individual, escala e pagamentos. O relatório aberto pelo Financeiro usa o período selecionado e inclui bruto, INSS, imposto de renda e líquido estimados. Observações são opcionais. PDF é relatório, não backup restaurável.

## Compilação automática

Os workflows **Compilar Plantão na Mão iOS 1.6** e **Extrair projeto iOS 1.6 automaticamente** são acionados pela branch main e permitem execução manual. A geração do IPA Release é independente dos testes de interface para não bloquear o pacote quando os simuladores do GitHub estiverem indisponíveis. O empacotamento verifica que a extensão .appex está incluída.

Baixe os resultados em Artifacts. O IPA automático é **sem assinatura Apple**. Para manter seus dados, atualize a instalação anterior com o mesmo Bundle ID e assinatura compatível, sem desinstalar.

## Testes

`bash scripts/check-models.sh` valida valores, preço por hora, descontos, períodos, histórico mensal, migração e conciliação em dois fusos. As verificações de modelos também cobrem as quatro antecedências, virada de dia/DST, fila de 64 avisos, payload de navegação e confirmação persistente de sincronização, inclusive edição offline e durante upload. Os testes iOS exercitam a substituição/cancelamento de lembretes com central simulada, bloqueio de permissão e falhas de agendamento. A entrega real precisa ser conferida no iPhone com a assinatura escolhida. Os testes iOS incluem PDFs, persistência, últimos três modelos e erros da sincronização. Os testes de interface verificam o dia atual na agenda, o calendário fixo, o acesso a Ajustes e o caminho selecionar dia 20 → reaproveitar preset → salvar → abrir o plantão no dia 20. As verificações de modelos cobrem datas exatas de competência, a leitura/regravação do arquivo, a projeção do calendário sem dados financeiros e as identificações de confirmação. Os testes locais não substituem a validação do compartilhamento entre processos no iPhone com a assinatura escolhida.

