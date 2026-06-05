local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Character = require(ReplicatedStorage.Classes.Character)

return Character.CreateSkin("Survivor", "XxNamedzxX", {
    Config = {
        Name = "SteadGuy",
        Quote = "Hey, its SteadGuy!",
        Price = 100,

        Origin = {},
    },
})