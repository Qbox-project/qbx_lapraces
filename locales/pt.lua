local Translations = {
    error = {
        toofast = "Não pode ir demasiado rápido",
        nocheckpoints = "Ainda não colocou nenhum ponto de controlo...",
        atleast10checkp = "Tem de ter pelo menos 10 pontos de controlo",
        higherthan15 = "Não pode ir além de 15",
        lowerthan2 = "Não pode ir abaixo de 2",
        mustbeinveh = "Tem de estar num veículo",
        pressagain = "Pressione [9] novamente para confirmar",
        editorcancelled = "Editor de corridas cancelado!",
        alreadymaking = "Já está a fazer uma corrida.",
        alreadyinrace = "Já está numa corrida...",
        notinarace = "Não está numa corrida...",
        playerfinished = "%{firstname} terminou: %{spot}º lugar",
        gobackorkick = "Volte ao início ou será expulso da corrida: %{seconds}s",
        namealreadyused = "Já existe uma corrida com este nome.",
        notauthorized = "Não foi autorizado a %{to}.",
        raceended = "Era o único na corrida, a corrida terminou",
        alreadyrunning = "A corrida já está a decorrer",
        notexist = "Esta corrida não existe :(",
        stoppingrace = "A parar a corrida: %{RaceId}",
        racenotopen = "Corrida não aberta: %{RaceId}",
        notcreator = "Não é o criador da corrida...",
        notstarted = "Esta corrida ainda não começou.",
        nomoreraces = "Não podem ser criadas mais corridas!",
    },
    success = {
        savedrace = "Corrida: %{racename} foi guardada!",
        finishedbest = "Corrida terminada em %{time}, com a melhor volta: %{best}",
        finished = "Corrida terminada em: %{time}",
        start = "VAI!",
        cancreate = "As corridas podem ser criadas novamente!",
    },
    primary = {
        LeaveRace = "Terminou a corrida!",
        startinten = "A corrida vai começar dentro de 10 segundos",
    },
    general = {
        CheckL = "Ponto de Controlo L",
        CheckR = "Ponto de Controlo R",
        DNF = "DNF",
        unknown = "Desconhecido",
        dothis = "fazer isto",
        createraces = " criar corridas"
    },
    phonenotif = {
        wonWR = "Ganhou o WR de %{Racename} com um tempo de: %{timeof}!",
        wonWR2 = "Ganhou o WR de %{Racename} com um tempo de: %{timeof}!",
        joinedrace = "%{firstname}. %{lastname} entrou na corrida!",
        LeaveRace = "%{firstname}. %{lastname} saiu da corrida!",
    },
    commands = {
        cancelrace = "Cancelar corrida em andamento...",
        togglesetup = "Ligar/desligar configuração de corrida"
    }
}

if GetConvar('qb_locale', 'en') == 'pt' then
    Lang = Locale:new({
        phrases = Translations,
        warnOnMissing = true,
        fallbackLang = Lang,
    })
end
