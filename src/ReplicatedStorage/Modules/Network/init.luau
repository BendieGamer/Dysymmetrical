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

--!native

local RunService = game:GetService("RunService")

local DataTypes = require(script.DataTypes)

--- Class used to connect the server and the clients more efficiently by encapsulating everything in a single place.
local Network = {
    Instances = {
        -- REMOTE_EVENT = nil,
        -- REMOTE_FUNCTION = nil,
        -- UREMOTE_EVENT = nil,
        -- BINDABLE_EVENT = nil,
    },
    _Equivalents = {
        REMOTE_EVENT = "RemoteEvent",
        REMOTE_FUNCTION = "RemoteFunction",
        UREMOTE_EVENT = "UnreliableRemoteEvent",
        BINDABLE_EVENT = "BindableEvent",
    },
    Connections = {},
    -- InstanceCreator = nil,
    ServiceLive = false,
    Debug = {
        ReceivedPackets = true,
        SentPackets = true,
    },
}

--- Waits until the networking service is live for usage.
--- 
--- Should only be used internally.
function Network:WaitForInit()
    while not self:IsLive() do
        task.wait()
    end
end

--- Initializes the networking system in the current environment.
function Network:Init()
    for Name, _ in self._Equivalents do
        self.Connections[Name] = {}
    end

    local function OnRemoteEventPacket(Player: Player?, Args: {any}, Type: "REMOTE_EVENT" | "UREMOTE_EVENT" | "BINDABLE_EVENT")
        --safety first gng
        if RunService:IsServer() and not Player then
            return
        end

        local Name, DecodedArgs = self:_UnpackArgumentsFromNetwork(Args)

        if self.Debug.ReceivedPackets then
            print(`[DysNetworking (DEBUG)] Received event of type "{Type}" with name "{Name}" and a size of {buffer.len(Args[1])} bytes.`)
        end

        local CallbackList = self.Connections[Type][Name]
        if not CallbackList then
            return
        end

        for callback, _ in CallbackList do
            if Type ~= "BINDABLE_EVENT" and Player then
                task.spawn(callback, Player, unpack(DecodedArgs))
            else
                task.spawn(callback, unpack(DecodedArgs))
            end
        end
    end

    local function OnRemoteFunctionPacket(Player: Player?, Args: {any}): any
        --safety first gng
        if RunService:IsServer() and not Player then
            return
        end

        local Name, DecodedArgs = self:_UnpackArgumentsFromNetwork(Args)

        if self.Debug.ReceivedPackets then
            print(`[DysNetworking (DEBUG)] Received "REMOTE_FUNCTION" event with name "{Name}" and size "{buffer.len(Args[1])}".`)
        end

        local Callback = self.Connections["REMOTE_FUNCTION"][Name]
        if not Callback then
            return
        end

        local Results = Player ~= nil and { Callback(Player, unpack(DecodedArgs)) } or { Callback(unpack(DecodedArgs)) }
        local CompressedResults = self:_PackArgumentsForNetwork("", Results) --using a dummy name, ignore

        return CompressedResults
    end

    if RunService:IsServer() then
        game:BindToClose(function()
            self:Destroy()
        end)

        local TypeFolder = script:FindFirstChild("Types")
        if not TypeFolder then
            TypeFolder = Instance.new("Folder")
            TypeFolder.Name = "Types"
            TypeFolder.Parent = script
        end

        for Name, InstName in self._Equivalents do
            local Inst = TypeFolder:FindFirstChild(InstName)
            if not Inst then
                Inst = Instance.new(InstName)
                Inst.Name = Name
                Inst.Parent = TypeFolder
            end
            self.Instances[Name] = Inst

            if Name == "REMOTE_FUNCTION" then
                Inst.OnServerInvoke = OnRemoteFunctionPacket
                continue
            end

            if Name == "BINDABLE_EVENT" then
                Inst.Event:Connect(function(Args: {any})
                    OnRemoteEventPacket(nil, Args, Name)
                end)

                continue
            end

            Inst.OnServerEvent:Connect(function(Player: Player, Args: {any})
                OnRemoteEventPacket(Player, Args, Name)
            end)
        end
    else
        local EventFolder = script:FindFirstChild("Types") or script:WaitForChild("Types")

        for Name, _ in self._Equivalents do
            self.Instances[Name] = EventFolder:FindFirstChild(Name) or EventFolder:WaitForChild(Name)

            if Name == "REMOTE_FUNCTION" then
                self.Instances[Name].OnClientInvoke = function(Args: {any}): any
                    return OnRemoteFunctionPacket(nil, Args)
                end
                
                continue
            end

            if Name == "BINDABLE_EVENT" then
                self.Instances[Name].Event:Connect(function(Args: {any})
                    OnRemoteEventPacket(nil, Args, Name)
                end)

                continue
            end

            self.Instances[Name].OnClientEvent:Connect(function(Args: {any})
                OnRemoteEventPacket(nil, Args, Name)
            end)
        end
    end

    self.ServiceLive = true
end

--- Adds a connection to a specific event / function instance.
--- @param name                    (`string`):      The name of the instance.
--- @param Type                    (`string`):      The type of the instance.
--- @param Callback                (`function`):    The code that will run when the connection is fired.
--- @return `RBXScriptConnection`                   The set connection for further usage in the script from where this is called.
function Network:SetConnection(name: string, Type: "REMOTE_EVENT" | "UREMOTE_EVENT" | "REMOTE_FUNCTION" | "BINDABLE_EVENT", Callback: (...any) -> (...any)): RBXScriptConnection
    if #name > 255 then
        warn(`[DysNetworking:SetConnection()] Can't assign connection with name "{name}" because it's too long! Try to shorten it a bit.`)
        return
    end
    
    self:WaitForInit()

    if self.Connections[Type][name] == nil and Type ~= "REMOTE_FUNCTION" then
        self.Connections[Type][name] = {}
    end
    if Type == "REMOTE_FUNCTION" then
        self.Connections[Type][name] = Callback
    else
        self.Connections[Type][name][Callback] = true
    end

    return {
        Connected = true,
        Disconnect = function(Connection)
            self.Connections[Type][name][Callback] = nil
            Connection.Connected = false
        end,
        Destroy = function(Connection)
            Connection:Disconnect()
        end,
    }
end

--- Destroys the Network instance. Only called when the server closes.
function Network:Destroy()
    script:ClearAllChildren()
    for _, Type in self.Connections do
        for EventKey, Event in Type do
            if typeof(Event) == "table" then
                for Key, _ in Event do
                    Event[Key] = nil
                end
                continue
            end
            Type[EventKey] = nil
        end
    end
end

--- Fires a specific client's event / function connections.
--- @param target  (`Player`):  The target client whose connections will be fired.
--- @param name    (`string`):  The name of the desired event / function
--- @param Type    (`string`):  The type of instance to fire the connections of
--- @param ...                  Any parameters to pass to the connection
function Network:FireClientConnection(target: Player | {Player}, name: string, Type: "REMOTE_EVENT" | "UREMOTE_EVENT" | "REMOTE_FUNCTION", ...): any | nil
    if #name > 255 then
        warn(`[DysNetworking:FireClientConnection()] Can't fire connection with name "{name}" because it's too long! Try to shorten it a bit.`)
        return
    end

    self:WaitForInit()

    if not RunService:IsServer() then
        warn("[DysNetworking:FireClientConnection()] This function shouldn't be called from the client. Make sure that it isn't!", debug.traceback())
        return
    end

    local event = self.Instances[Type]
    if not event then
        warn(`[DysNetworking:FireClientConnection()] Event {name} couldn't be fired because it doesn't exist! Are you sure you're spelling the type correctly? ({Type})`, debug.traceback())
        return
    end

    local Arguments = {...}
    local CompressedArguments = self:_PackArgumentsForNetwork(name, Arguments)

    local function Fire(player: Player, ...)
        if self.Debug.SentPackets then
            print(`[DysNetworking (DEBUG)] Fired event of type "{Type}" with name "{name}".\n{debug.traceback()}`)
        end

        if Type == "REMOTE_FUNCTION" then
            local Results = event:InvokeClient(player, ...)
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
            Results[player.UserId] = Fire(player, CompressedArguments)
        end
        return Results
    end
    
    return Fire(target, CompressedArguments)
end

--- Fires an event's connections to every single connected client. If the type of the object is a RemoteFunction, it won't do anything.
--- @param name    (`string`):  The name of the desired event
--- @param Type    (`string`):  The type of the event (Reliable / Unreliable)
--- @param ...                  Any parameters to pass to the connection
function Network:FireAllClientConnection(name: string, Type: "REMOTE_EVENT" | "UREMOTE_EVENT", ...)
    if #name > 255 then
        warn(`[DysNetworking:FireAllClientConnection()] Can't fire connection with name "{name}" because it's too long! Try to shorten it a bit.`)
        return
    end

    self:WaitForInit()

    if not RunService:IsServer() then
        warn("[DysNetworking:FireAllClientConnection()] This function shouldn't be called from the client. Make sure that it isn't!", debug.traceback())
        return
    end

    if Type == "REMOTE_FUNCTION" or Type == "BINDABLE_EVENT" then
        warn(`[DysNetworking:FireAllClientConnection()] Event of type {Type} cannot be fired to every client at once!`, debug.traceback())
        return
    end

    local instance = self.Instances[Type]
    if not instance then
        warn(`[DysNetworking:FireAllClientConnection()] Event {name} couldn't be fired because it doesn't exist! Are you sure you're connecting it to anything?`, debug.traceback())
        return
    end

    local Arguments = {...}
    local CompressedArguments = self:_PackArgumentsForNetwork(name, Arguments)

    if self.Debug.SentPackets then
        print(`[DysNetworking (DEBUG)] Fired event of type "{Type}" with name "{name}".\n{debug.traceback()}`)
    end

    instance:FireAllClients(CompressedArguments)
end

--- Fires a server's event / function connections.
--- @param name    (`string`):  The name of the desired event / function
--- @param Type    (`string`):  The type of instance to fire the connections of
--- @param ...                  Any parameters to pass to the connection
function Network:FireServerConnection(name: string, Type: "REMOTE_EVENT" | "UREMOTE_EVENT" | "REMOTE_FUNCTION", ...): any | nil
    if #name > 255 then
        warn(`[DysNetworking:FireServerConnection()] Can't fire connection with name "{name}" because it's too long! Try to shorten it a bit.`)
        return
    end

    self:WaitForInit()

    if not RunService:IsClient() then
        warn("[DysNetworking:FireServerConnection()] This function shouldn't be called from the server. Make sure that it isn't!", debug.traceback())
        return
    end

    local instance = self.Instances[Type]
    if not instance then
        warn(`[DysNetworking:FireServerConnection()] Event {name} couldn't be fired because it doesn't exist! Are you sure you're spelling the type correctly? ({Type})`, debug.traceback())
        return
    end

    local Arguments = {...}
    local CompressedArguments = self:_PackArgumentsForNetwork(name, Arguments)

    if self.Debug.SentPackets then
        print(`[DysNetworking (DEBUG)] Fired event of type "{Type}" with name "{name}".\n{debug.traceback()}`)
    end

    if Type == "REMOTE_FUNCTION" then
        local Results = instance:InvokeServer(CompressedArguments)
        local _, DecompressedResults = self:_UnpackArgumentsFromNetwork(Results)
        return unpack(DecompressedResults)
    end

    instance:FireServer(CompressedArguments)
    
    return
end

--- Fires a BindableEvent's connections
--- @param name (`string`): The name of the desired BindableEvent
--- @param ...              Any parameters to pass to the connection
function Network:FireConnection(name: string, ...)
    if #name > 255 then
        warn(`[DysNetworking:FireConnection()] Can't fire connection with name "{name}" because it's too long! Try to shorten it a bit.`)
        return
    end

    self:WaitForInit()

    local Bindable = self.Instances["BINDABLE_EVENT"]
    if not Bindable then
        warn(`[DysNetworking:FireServerConnection()] Event {name} couldn't be fired because the main BindableEvent instance is missing! Are you sure the module is initializing properly?`, debug.traceback())
        return
    end

    local Arguments = {...}
    local CompressedArguments = self:_PackArgumentsForNetwork(name, Arguments)

    if self.Debug.SentPackets then
        print(`[DysNetworking (DEBUG)] Fired event of type "BINDABLE_EVENT" with name "{name}".\n{debug.traceback()}`)
    end

    Bindable:Fire(CompressedArguments)
end

--- Returns an object instance
--- @param Type    (`string`):    The type of the desired instance inside of the script (e. g. "REMOTE_EVENT")
--- @return `any`                 May return the desired instance
function Network:GetInstance(Type: "REMOTE_EVENT" | "UREMOTE_EVENT" | "REMOTE_FUNCTION" | "BINDABLE_EVENT")
    --this function doesn't get used but it might be useful for some people idk -dys
    self:WaitForInit()

    local Event = self.Instances[Type]
    if not Event then
        warn(`[DysNetworking:GetInstance()] Event of type "{Type}" couldn't be found! Are you sure you're spelling it correctly?`, debug.traceback())
        return
    end
    return Event
end

--- Checks if the Network service is available in the current environment
function Network:IsLive()
    return self.ServiceLive
end

--- Packs every argument of a fire to lower network usage when sending them.
function Network:_PackArgumentsForNetwork(Name: string, Arguments: {any})
    --calculate the total size of the buffer
    local TotalSize = 1 + #Name --1 for string length and the length itself
    local PreparedArgs = {} --param cache
    local InstanceList = {} --instance cache

    for _, Value in ipairs(Arguments) do
        --get le tag
        local Tag = DataTypes.GetTagFromValue(Value)
        
        --get le size
        local PayloadSize = DataTypes.GetPayloadSize(Tag, Value)
        
        --add le size to total + 1 for the tag
        TotalSize += (1 + PayloadSize)
        
        table.insert(PreparedArgs, {
            Tag = Tag,
            Value = Value,
        })
    end

    --create the damn buffer
    local PacketBuffer = buffer.create(TotalSize)
    buffer.writeu8(PacketBuffer, 0, #Name)
    buffer.writestring(PacketBuffer, 1, Name)
    local Offset = 1 + #Name

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

    local NameLength = buffer.readu8(PacketBuffer, 0)
    local Name = buffer.readstring(PacketBuffer, 1, NameLength)

    local Offset = 1 + NameLength
    local BufLength = buffer.len(PacketBuffer)
    local Unpacked = {}

    --loop until the whole buffer is read
    while Offset < BufLength do
        --le tag
        local Tag = buffer.readu8(PacketBuffer, Offset)
        Offset += 1
        
        --get the shit
        local Value, NewCursor = DataTypes.Readers[Tag](PacketBuffer, Offset, InstanceList)
        
        --put it in the param table
        table.insert(Unpacked, Value)
        --increase the shit
        Offset = NewCursor
    end

    --FINALLY return the thing for usage
    return Name, Unpacked
end

return Network
