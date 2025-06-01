Config = {}

Config.FrameWork = 'esx' -- Select the framework being used: 'esx' for ESX Framework or 'qb' for QBCore Framework.
Config.AutoExpire = 5 -- Time in minutes after which a robbery request will automatically expire if not accepted.
Config.policejobs = {"sheriff", "police"} -- List of police jobs that can respond to robberies.
Config.AutoVersionChecker = false -- Enable or disable the automatic version checker.
Config.Robberies = {
    {
        name = "Robo ATM",
        minimumPolice = 2,
    },
    {
        name = "Robo a badulaques, gasolineras y licorerías",
        minimumPolice = 2,
    },
    {
        name = "Robo a Casas",
        minimumPolice = 3,
    },
    {
        name = "Robo a tiendas de ropa, peluquerías y tiendas de tatuajes",
        minimumPolice = 2,
    },
    {
        name = "Robo a Ammu-Nation",
        minimumPolice = 2,
    },
    {
        name = "Asalto a Yate",
        minimumPolice = 6,
    },
    {
        name = "Asalto a Joyería",
        minimumPolice = 4,
    },
    {
        name = "Robo a Fleeca",
        minimumPolice = 4,
    },
    {
        name = "Robo Furgón Blindado",
        minimumPolice = 3,
    },
    {
        name = "Robo a Farmacia",
        minimumPolice = 2,
    },
    {
        name = "Robo a Pacific Bank",
        minimumPolice = 6,
    },
    {
        name = "Robo a Humane Labs",
        minimumPolice = 6,
    },
    {
        name = "Robo a Casino",
        minimumPolice = 6,
    },
}