
local Translations = {
    error = {
        toofast = "Nemůžeš jet příliš rychle",
        nocheckpoints = "Zatím jsi neumístil(a) žádné kontrolní body..",
        atleast10checkp = "Musíš mít alespoň 10 kontrolních bodů",
        higherthan15 = "Nemůžeš jít výše než 15",
        lowerthan2 = "Nemůžeš jít níže než 2",
        mustbeinveh = "Musíš být v vozidle",
        pressagain = "Stiskněte [9] znovu pro potvrzení",
        editorcancelled = "Editor závodu zrušen!",
        alreadymaking = "Již vytváříš závod.",
        alreadyinrace = "Již jsi v závodě..",
        notinarace = "Nejsi v závodě..",
        playerfinished = "%{firstname} dokončil(a): %{spot} místo",
        gobackorkick = "Vrať se zpět na start nebo budeš vyhozen(a) ze závodu: %{seconds}s",
        namealreadyused = "Již existuje závod s tímto názvem.",
        notauthorized = "Nemáš oprávnění k provedení akce: %{to}.",
        raceended = "Byl jsi jediný(á) v závodě, závod skončil",
        alreadyrunning = "Závod již probíhá",
        notexist = "Tento závod neexistuje :(",
        stoppingrace = "Zastavuji závod: %{RaceId}",
        racenotopen = "Závod není otevřen: %{RaceId}",
        notcreator = "Nejsi tvůrcem závodu..",
        notstarted = "Tento závod ještě nezačal.",
        nomoreraces = "Nelze vytvářet více závodů!",
    },
    success = {
        savedrace = "Závod: %{racename} uložen!",
        finishedbest = "Závod dokončen za %{time}, s nejlepším kolem: %{best}",
        finished = "Závod dokončen za: %{time}",
        start = "START!",
        cancreate = "Závody mohou být znovu vytvořeny!",
    },
    primary = {
        LeaveRace = "Dokončil(a) jsi závod!",
        startinten = "Závod začne za 10 sekund",
    },
    general = {
        CheckL = "Kontrolní bod L",
        CheckR = "Kontrolní bod R",
        DNF = "DNF",
        unknown = "Neznámý",
        dothis = "udělat to",
        createraces = " vytvářet závody"
    },
    phonenotif = {
        wonWR = "Vyhrál(a) jsi WR z %{Racename} odpojeno s časem: %{timeof}!",
        wonWR2 = "Vyhrál(a) jsi WR z %{Racename} položeno s časem: %{timeof}!",
        joinedrace = "%{firstname}. %{lastname} se připojil(a) do závodu!",
        LeaveRace = "%{firstname}. %{lastname} se odhlásil(a) ze závodu!",
    },
    commands = {
        cancelrace = "Zrušit probíhající závod..",
        togglesetup = "Zapnout / vypnout nastavení závodu"
    }
}

if GetConvar('qb_locale', 'en') == 'cs' then
    Lang = Locale:new({
        phrases = Translations,
        warnOnMissing = true,
        fallbackLang = Lang,
    })
end
--translate by stepan_valic