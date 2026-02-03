--[[
	Thanks for using DysNetworking!
	Every bit of documentation is scattered through this same module.
	I tried to document it as well as I could to make it as understandable as possible.
	You'll still have to know some coding to work properly with this.
	Anyway, have fun making your games!
	
	
	
	To access this module's functions, just require it from anywhere, from any kind of script.
	For example:
	
		---CLIENT---
		local DysNetworking = require(game:GetService("ReplicatedStorage").DysNetworking)
		DysNetworking:SetConnection("EXAMPLE_1", "REMOTE_EVENT", function(param1: string)
			print(param1)
		end)
		
		DysNetworking:FireServerConnection("EXAMPLE_2", "REMOTE_EVENT", "printing from server!")
		
		---SERVER---
		local DysNetworking = require(game:GetService("ReplicatedStorage").DysNetworking)
		DysNetworking:FireAllClients("EXAMPLE_1", "REMOTE_EVENT", "printing!") --where `"printing!"` is `param1` in the client.
		--If you do `FireClient` instead, you'll have to specify the target player before anything.
		
		--When connecting from the server to a remote, the first parameter **MUST** always be the player that called the event, just like with Remote instances.
		DysNetworking:SetConnection("EXAMPLE_2", "REMOTE_EVENT", function(sourcePlayer: Player, param1: string)
			print(sourcePlayer.Name.." called this event!")
			print(param1)
		end)
		
	That's it, pretty simple.
	Everything works like your traditional Remote & Bindable instances.
	
	Though, this module will have to be initted in both sides before it can be properly used.
	For that, just create a script in `ServerScriptService` and another one in `StarterPlayerScripts` that requires it and calls `DysNetworking:Init()`.
	In the template there are two scripts that already do this and destroy themselves when they do so, so you can just use those. :p
	
	That's it! :>
]]

local RunService = game:GetService("RunService")

local DataTypes = require(script.DataTypes)

--- Class used to connect the server and the clients more efficiently by encapsulating everything in a single place.
local Network = {
    Folders = {
        -- REMOTE_EVENT = nil,
        -- REMOTE_FUNCTION = nil,
        -- UREMOTE_EVENT = nil,
        -- BINDABLE_EVENT = nil,
    },
    _FolderNames = {
        "REMOTE_EVENT",
        "REMOTE_FUNCTION",
        "UREMOTE_EVENT",
        "BINDABLE_EVENT",
    },
    -- InstanceCreator = nil,
    ServiceLive = false,
}

--- Initializes the networking system in the current environment.
function Network:Init()
    if RunService:IsServer() then
        game:BindToClose(function()
            self:Destroy()
        end)

        for _, name in self._FolderNames do
            local Folder = Instance.new("Folder")
            Folder.Name = name
            self.Folders[name] = Folder
            Folder.Parent = script
        end

        self.InstanceCreator = Instance.new("RemoteFunction")
        self.InstanceCreator.Name = "InstanceCreator"
        self.InstanceCreator.Parent = script

        self.InstanceCreator.OnServerInvoke = function(_player: Player, name: string, Type: "REMOTE_EVENT" | "UREMOTE_EVENT" | "REMOTE_FUNCTION" | "BINDABLE_EVENT")
            return self:_CreateInstance(name, Type)
        end
    else
        for _, name in self._FolderNames do
            self.Folders[name] = script:FindFirstChild(name) or script:WaitForChild(name)
        end

        if not script:FindFirstChild("InstanceCreator") then
            while not script.InstanceCreator do
                task.wait()
            end
        end

        self.InstanceCreator = script.InstanceCreator
    end

    self.ServiceLive = true
end

local InstanceConstructorTable = {
    REMOTE_EVENT = function(): RemoteEvent
        return Instance.new("RemoteEvent")
    end,
    UREMOTE_EVENT = function(): UnreliableRemoteEvent
        return Instance.new("UnreliableRemoteEvent")
    end,
    REMOTE_FUNCTION = function(): RemoteFunction
        return Instance.new("RemoteFunction")
    end,
    BINDABLE_EVENT = function(): BindableEvent
        return Instance.new("BindableEvent")
    end,
}
--- Creates an instance of a specific type for later usage.
--- @param name                                                                     (`string`): The name of the instance.
--- @param Type                                                                     (`string`): The desired type of the instance.
--- @return `RemoteEvent | UnreliableRemoteEvent | RemoteFunction | BindableEvent`              The instance that has been created.
function Network:_CreateInstance(name: string, Type: "REMOTE_EVENT" | "UREMOTE_EVENT" | "REMOTE_FUNCTION" | "BINDABLE_EVENT"): RemoteEvent | UnreliableRemoteEvent | RemoteFunction | BindableEvent
    if not RunService:IsServer() then
        warn("[DysNetworking:_CreateInstance()] This function shouldn't be called from the client. Make sure that it isn't!", debug.traceback())
        return
    end

    local instance = InstanceConstructorTable[Type]

    if instance == nil then
        warn(`[DysNetworking:_CreateInstance()] Type {Type} isn't a kind of remote / bindable! Are you sure you're spelling it right?`, debug.traceback())
        return
    end

    instance = instance()
    instance.Name = name
    instance.Parent = self.Folders[Type]
    return instance
end

--- Sets up a connection for an instance depending on the type.
--- @param instance (`RemoteEvent | UnreliableRemoteEvent | RemoteFunction | BindableEvent`):   The instance to set up the connection of.
--- @param Callback (`function`):                                                               The code that will execute when the connection fires.
function Network:_SetupConnection(instance: RemoteEvent | UnreliableRemoteEvent | RemoteFunction | BindableEvent, Callback: (any) -> (any)): RBXScriptConnection | nil
    if instance:IsA("BindableEvent") then
        return instance.Event:Connect(function(...)
            local Arguments = {...}
            local Decompressed = self:_UnpackArgumentsFromNetwork(Arguments)

            return Callback(unpack(Decompressed))
        end)
    end

    if RunService:IsServer() then
        if instance:IsA("RemoteEvent") or instance:IsA("UnreliableRemoteEvent") then
            return instance.OnServerEvent:Connect(function(player, ...)
                local Arguments = {...}
                local Decompressed = self:_UnpackArgumentsFromNetwork(Arguments)

                Callback(player, unpack(Decompressed))
            end)
        elseif instance:IsA("RemoteFunction") then
            instance.OnServerInvoke = function(player, ...)
                local Arguments = {...}
                local Decompressed = self:_UnpackArgumentsFromNetwork(Arguments)

                -- Handle the callback and then compress the return value

                local Result = { Callback(player, unpack(Decompressed)) }
                local CompressedResult = self:_PackArgumentsForNetwork(Result)
                return unpack(CompressedResult)
            end
        end
    else
        if instance:IsA("RemoteEvent") or instance:IsA("UnreliableRemoteEvent") then
            return instance.OnClientEvent:Connect(function(...)
                local Arguments = {...}
                local Decompressed = self:_UnpackArgumentsFromNetwork(Arguments)

                Callback(unpack(Decompressed))
            end)
        elseif instance:IsA("RemoteFunction") then
            instance.OnClientInvoke = function(...)
                local Arguments = {...}
                local Decompressed = self:_UnpackArgumentsFromNetwork(Arguments)

                local Result = { Callback(unpack(Decompressed)) }
                local CompressedResult = self:_PackArgumentsForNetwork(Result)
                
                return unpack(CompressedResult)
            end
        end
    end

    return
end

--- Adds a connection to a specific event / function instance.
--- @param name                    (`string`):      The name of the instance.
--- @param Type                    (`string`):      The type of the instance.
--- @param Callback                (`function`):    The code that will run when the connection is fired.
--- @return `RBXScriptConnection`                   The set connection for further usage in the script from where this is called.
function Network:SetConnection(name: string, Type: "REMOTE_EVENT" | "UREMOTE_EVENT" | "REMOTE_FUNCTION" | "BINDABLE_EVENT", Callback: (...any) -> (...any)): RBXScriptConnection
    while not self:IsLive() do
        task.wait()
    end

    local instance
    if RunService:IsServer() then
        if not self.Folders[Type]:FindFirstChild(name) then
            instance = self:_CreateInstance(name, Type)
        else
            instance = self.Folders[Type]:FindFirstChild(name)
        end
    else
        if not self.Folders[Type]:FindFirstChild(name) then
            instance = self.InstanceCreator:InvokeServer(name, Type)
        else
            instance = self.Folders[Type]:FindFirstChild(name)
        end
    end

    return self:_SetupConnection(instance, Callback)
end

--- Destroys the Network instance. Only called when the server closes.
function Network:Destroy()
    for _, RemoteFunction in self.Folders.REMOTE_FUNCTION:GetChildren() do
        if not RemoteFunction:IsA("RemoteFunction") then
            continue
        end

        RemoteFunction.OnServerInvoke = function() end
    end
end

--- Fires a specific client's event / function connections.
--- @param target  (`Player`):  The target client whose connections will be fired.
--- @param name    (`string`):  The name of the desired event / function
--- @param Type    (`string`):  The type of instance to fire the connections of
--- @param ...                  Any parameters to pass to the connection
function Network:FireClientConnection(target: Player | {Player}, name: string, Type: "REMOTE_EVENT" | "UREMOTE_EVENT" | "REMOTE_FUNCTION", ...): any | nil
    while not self:IsLive() do
        task.wait()
    end

    if not RunService:IsServer() then
        warn("[DysNetworking:FireClientConnection()] This function shouldn't be called from the client. Make sure that it isn't!", debug.traceback())
        return
    end

    local event = self.Folders[Type]:FindFirstChild(name)
    if not event then return end
    local Arguments = {...}
    local CompressedArguments = self:_PackArgumentsForNetwork(Arguments)

    local function Fire(player: Player, ...)
        if event:IsA("RemoteFunction") then
            local Results = { event:InvokeClient(player, ...) }
            local DecompressedResults = self:_UnpackArgumentsFromNetwork(Results)
            return unpack(DecompressedResults)
        else
            event:FireClient(player, ...)
        end
        return
    end

    if typeof(target) == "table" then
        local Results = {}
        for _, player: Player in target do
            Results[player.UserId] = Fire(player, unpack(CompressedArguments))
        end
        return Results
    end
    
    return Fire(target, unpack(CompressedArguments))
end

--- Fires an event's connections to every single connected client. If the type of the object is a RemoteFunction, it won't do anything.
--- @param name    (`string`):  The name of the desired event
--- @param Type    (`string`):  The type of the event (Reliable / Unreliable)
--- @param ...                  Any parameters to pass to the connection
function Network:FireAllClientConnection(name: string, Type: "REMOTE_EVENT" | "UREMOTE_EVENT", ...)
    while not self:IsLive() do
        task.wait()
    end

    if not RunService:IsServer() then
        warn("[DysNetworking:FireAllClientConnection()] This function shouldn't be called from the client. Make sure that it isn't!", debug.traceback())
        return
    end

    if Type == "REMOTE_FUNCTION" or Type == "BINDABLE_EVENT" then
        warn(`[DysNetworking:FireAllClientConnection()] Event of type {Type} cannot be fired to every client at once!`, debug.traceback())
        return
    end

    local instance = self.Folders[Type]:FindFirstChild(name)
    if not instance then
        warn(`[DysNetworking:FireAllClientConnection()] Event {name} couldn't be fired because it doesn't exist! Are you sure you're connecting it to anything?`, debug.traceback())
        return
    end

    local Arguments = {...}
    local CompressedArguments = self:_PackArgumentsForNetwork(Arguments)

    instance:FireAllClients(unpack(CompressedArguments))
end

--- Fires a server's event / function connections.
--- @param name    (`string`):  The name of the desired event / function
--- @param Type    (`string`):  The type of instance to fire the connections of
--- @param ...                  Any parameters to pass to the connection
function Network:FireServerConnection(name: string, Type: "REMOTE_EVENT" | "UREMOTE_EVENT" | "REMOTE_FUNCTION", ...): any | nil
    while not self:IsLive() do
        task.wait()
    end

    if not RunService:IsClient() then
        warn("[DysNetworking:FireServerConnection()] This function shouldn't be called from the server. Make sure that it isn't!", debug.traceback())
        return
    end

    local instance = self.Folders[Type]:FindFirstChild(name)
    if not instance then
        warn(`[DysNetworking:FireServerConnection()] Event {name} couldn't be fired because it doesn't exist! Are you sure you're connecting it to anything?`, debug.traceback())
        return
    end

    local Arguments = {...}
    local CompressedArguments = self:_PackArgumentsForNetwork(Arguments)

    if instance:IsA("RemoteFunction") then
        local Results = { instance:InvokeServer(unpack(CompressedArguments)) }
        local DecompressedResults = self:_UnpackArgumentsFromNetwork(Results)
        return unpack(DecompressedResults)
    end

    instance:FireServer(unpack(CompressedArguments))
    
    return
end

--- Fires a BindableEvent's connections
--- @param name (`string`): The name of the desired BindableEvent
--- @param ...              Any parameters to pass to the connection
function Network:FireConnection(name: string, ...)
    while not self:IsLive() do
        task.wait()
    end

    local Bindable = self.Folders["BINDABLE_EVENT"]:FindFirstChild(name)
    if not Bindable then
        warn(`[DysNetworking:FireConnection] Event {name} couldn't be fired because it doesn't exist! Are you sure you're connecting it to anything?`, debug.traceback())
        return
    end

    local Arguments = {...}
    local CompressedArguments = self:_PackArgumentsForNetwork(Arguments)

    Bindable:Fire(unpack(CompressedArguments))
end

--- Returns an object instance
--- @param name    (`string`):    The name of the desired instance
--- @param Type    (`string`):    The type of the desired instance inside of the script (e. g. "REMOTE_EVENT")
--- @return `any`                 May return the desired instance
function Network:GetInstance(name: string, Type: "REMOTE_EVENT" | "UREMOTE_EVENT" | "REMOTE_FUNCTION" | "BINDABLE_EVENT")
    --this function doesn't get used but it might be useful for some people idk -dys
    while not self:IsLive() do
        task.wait()
    end

    local Event = self.Folders[Type]:FindFirstChild(name)
    if not Event then
        warn(`[DysNetworking:GetInstance] Event {name} couldn't be found! Are you sure you're connecting it to anything?`, debug.traceback())
        return
    end
    return Event
end

--- Checks if the Network service is available in the current environment
function Network:IsLive()
    return self.ServiceLive and self:_FoldersAvailable()
end

--- Checks if every folder is available
function Network:_FoldersAvailable()
    local availableIndex = 0

    for _, folder in self.Folders do
        if folder ~= nil then
            availableIndex += 1
        end
    end

    return availableIndex == #self._FolderNames
end

--- Packs every argument of a fire to lower network usage when sending them.
function Network:_PackArgumentsForNetwork(Arguments: {any})
    --calculate the total size of the buffer
    local TotalSize = 0
    local PreparedArgs = {} --param cache
    local InstanceList = {} --instance cache

    for _, Value in ipairs(Arguments) do
        local WriteValue = Value --JUST IN FUCKING CASE.

        --get le tag
        local Tag = DataTypes.GetTagFromValue(WriteValue)
        
        --get le size
        local PayloadSize = DataTypes.GetPayloadSize(Tag, WriteValue)
        
        --add le size to total + 1 for the tag
        TotalSize += (1 + PayloadSize)
        
        table.insert(PreparedArgs, {
            Tag = Tag,
            Value = WriteValue,
        })
    end

    --create the damn buffer
    local PacketBuffer = buffer.create(TotalSize)
    local Offset = 0

    for _, Item in ipairs(PreparedArgs) do
        --write le tag first
        buffer.writeu8(PacketBuffer, Offset, Item.Tag)
        Offset += 1
        
        --fucking write it and increment the offset based on it
        Offset = DataTypes.Writers[Item.Tag](PacketBuffer, Offset, Item.Value, InstanceList)
    end

    --return as a table prematurely to prevent roblox's networking from doing it itself
    return {PacketBuffer, InstanceList}
end

--- Unpacks packed arguments from a fire to use properly in a connection.
function Network:_UnpackArgumentsFromNetwork(Arguments: {any})
    --the only argument should be the buffer
    local PacketBuffer = Arguments[1]
    local InstanceList = Arguments[2] or {}
    --if it's not, FUCK YOU YOU DEAL WITH IT
    if typeof(PacketBuffer) ~= "buffer" then
        return Arguments
    end

    local Offset = 0
    local BufLength = buffer.len(PacketBuffer)
    local Unpacked = {}

    --loop until the whole buffer is read
    while Offset < BufLength do
        --le tag
        local Tag = buffer.readu8(PacketBuffer, Offset)
        Offset += 1
        
        --get the shit
        local Value, NewCursor = DataTypes.Readers[Tag](PacketBuffer, Offset, InstanceList)

        --get the damn instance from the list
        if Tag == DataTypes.Enum.Instance then
            Value = InstanceList[Value]
        end
        
        --put it in the param table
        table.insert(Unpacked, Value)
        --increase the shit
        Offset = NewCursor
    end

    --FINALLY return the thing for usage
    return Unpacked
end

return Network
