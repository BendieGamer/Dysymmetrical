script.Parent.Triggered:Connect(function(plr)
	require(game:GetService("ServerScriptService").Managers.PlayerManager.CharacterManager).SpawnAsCharacter(plr, {
		Name = "NullexVoyd",
		Role = "Killer",
	})
end)