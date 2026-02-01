local TypeUtils = {}

local Rand = Random.new()

--- Splits a path into multiple strings.
function TypeUtils.SplitStringPath(path: string): {string}
    return path:split(".")
end

--- Makes a copy of an entire table.
function TypeUtils.CopyTable<T>(CloneThis: T & {}) : T & {}
    local NewTable = {}

	for Key, Value in CloneThis do
		if typeof(Value) == "table" then
			NewTable[Key] = TypeUtils.CopyTable(Value)
            local MetaTable = getmetatable(Value)
            if MetaTable then
                setmetatable(NewTable[Key], MetaTable)
            end
		else
			NewTable[Key] = Value
		end
	end

	local MetaTable = getmetatable(CloneThis)
    if MetaTable then
        setmetatable(NewTable, MetaTable)
    end

	return NewTable
end

--- Checks if a table is either a dictionary or a numeric table.
--- 
--- Mixed tables (containing numbers and others as keys) will be treated as dictionaries as well.
--- 
--- This util is useless if the table is empty for obvious reasons.
function TypeUtils.IsTableADictionary<T>(Target: T & {}): boolean
    for key, _ in Target do
        if typeof(key) ~= "number" then
            return true
        end
    end
    
    return false
end

--- Shuffles a table to make it have a random order.
--- 
--- Dictionaries won't be accepted in this function as they already don't have a specific order.
function TypeUtils.ShuffleTable<T>(TableToShuffle: T & {}): T & {}
    if TypeUtils.IsTableADictionary(TableToShuffle) then
        warn("[TypeUtils.ShuffleTable()]: Can't shuffle table! A dictionary, which can't be reordered, has been passed!")

        return TableToShuffle
    end

    local currentShuffledIndex, shufflingItem

	for index = #TableToShuffle, 1, -1 do
		currentShuffledIndex = Rand:NextInteger(1, index)
		shufflingItem = TableToShuffle[index]
		TableToShuffle[index] = TableToShuffle[currentShuffledIndex]
		TableToShuffle[currentShuffledIndex] = shufflingItem
	end
	
	return TableToShuffle
end

--- Turns a dictionary into a table, removing the keys and making them numbers.
--- 
--- Primarily used for randomness as it isn't ordered in any way.
function TypeUtils.DictToTable<T>(Dictionary: {[any]: T}): {T}
    if TypeUtils.IsTableADictionary(Dictionary) then
        return Dictionary
    end

    local NewTable = {}

    for _, item in Dictionary do
        table.insert(NewTable, item)
    end

    return NewTable
end

--- Returns the amount of items there are in a dictionary.
--- 
--- Also works with tables but you can just do `#TableName` instead.
function TypeUtils.GetCountOfDict(dictionary: {[any]: any}): number
    local Count = 0

    if dictionary then
        for _, _ in dictionary do
            Count += 1
        end
    end
    
    return Count
end

--- Attempts to find a certain key or value in a dictionary.
--- 
--- May also work with numeric tables.
function TypeUtils.FindInDictionary<K, V>(Dictionary: {[K]: V}, Item: K | V, Type: "Key" | "Value"): (K, V)
    if Type == "Key" then
        for Key, Value in Dictionary do
            if Key == Item then
                return Key, Value
            end
        end
    elseif Type == "Value" then
        for Key, Value in Dictionary do
            if Value == Item then
                return Key, Value
            end
        end
    end

    return
end

--- Replaces or copies any values from `Source` into `Target`.
--- If you pass in a table variable, you don't have to get anything as it'll be replaced in that variable directly.
function TypeUtils.DeepTableOverwrite<T>(Target: T & {}, Source: {[any]: any}): T & {}
    if not Target or not Source then
        return
    end

	for key, value in Source do
		if typeof(value) == "table" then
			if typeof(Target[key]) ~= "table" then
                local MetaTable = getmetatable(value)
                if MetaTable then
                    Target[key] = setmetatable({}, MetaTable)
                else
                    Target[key] = {}
                end
			end
			TypeUtils.DeepTableOverwrite(Target[key], value)
            continue
		end
		Target[key] = value
	end

    return Target
end

--- Copies any values from `Source` into `Target`.
--- If you pass in a table variable, you don't have to get anything as it'll be replaced in that variable directly.
--- Differs from `Utils:DeepTableOverwrite` in that it doesn't overwrite existing values.
function TypeUtils.DeepTableWrite<T>(Target: T & {}, Source: {[any]: any}): T & {}
    if not Target or not Source then
        return
    end

	for key, value in Source do
		if typeof(value) == "table" then
			if typeof(Target[key]) ~= "table" then
                local MetaTable = getmetatable(value)
                if MetaTable then
                    Target[key] = setmetatable({}, MetaTable)
                else
                    Target[key] = {}
                end
			end
			TypeUtils.DeepTableWrite(Target[key], value)
            continue
		end
        if Target[key] == nil then
		    Target[key] = value
        end
	end

    return Target
end

--- Gets a random item from the provided table.
--- 
--- This also works with dictionaries.
function TypeUtils.GetRandomItemFromTable<T>(Target: T & {}): any
    -- turn into a table if it's a dictionary
    local UsedTable = TypeUtils.DictToTable(Target)

    -- if it's empty return nothing
    if #UsedTable <= 0 then
        return
    end

    -- if it only has one item just return the item
    if #UsedTable == 1 then
        return UsedTable[1]
    end

    -- return a random index from the table
    return UsedTable[Rand:NextInteger(1, #UsedTable)]
end

--- Splits a table into multiple chunks with size `ChunkSize`.
--- 
--- @return A table containing all chunks.
function TypeUtils.SplitTableIntoChunks<T>(TableToSplit: T & {}, ChunkSize: number): {T & {}}
    local Chunks = {}
    local CurrentChunk = {}

    for _, Item in ipairs(TypeUtils.DictToTable(TableToSplit)) do
        table.insert(CurrentChunk, Item)
        if #CurrentChunk > ChunkSize then
            table.insert(Chunks, CurrentChunk)
            CurrentChunk = {}
        end
    end

    if #CurrentChunk > 0 then
        table.insert(Chunks, CurrentChunk)
    end

    return Chunks
end

--[[
	Function for converting a ValueObject tree into a table.

	Used to turn the valueobjects used to store playerdata into a format we can save to the datastore.

	Eventually, this will probably be made two-way, and more functionality may be added to it.
]]--
function TypeUtils.ConvertInstanceTreeToTable(TargetInstance: Instance, Depth: number?): ({[string]: {any}})
	local tree = {}

	-- A cap for maximum allowed depth– leaving it arbitrary feels like a recipe for disaster 
	Depth = (Depth or -1) + 1

	-- Iterate through all of the instance's children
	for _index, value in ipairs(TargetInstance:GetChildren()) do

		-- If the child is a folder, run this function again on it to create another nest.
		if value:IsA("Folder") and Depth < 50 then -- Customize the depth cap as you please. Realistically, nothing will ever go this deep, but to avoid a permanant hang or an infinite loop, you can never be too sure...

			tree[value.Name] = TypeUtils.ConvertInstanceTreeToTable(value, Depth)

			-- If the child is a valueobject, grab its value and add it to the table.
		elseif value:IsA("ValueBase") then
			tree[value.Name] = value.Value
		end

	end

	-- Return the completed table to whatever called the function.
	return tree
end

--[=[
    Safely indexes an item from a table which search must be done in more than one step.
    
    For example, if I wanted to index an item in a table inside another table, and I'm not sure if it's gonna be there, that is a good use scenario.

    ```lua
        local Table = {}
        
        -- SCENARIO 1 --
        Table.Items = {
            Thing = "Hey!",
        }

        local ItemInTable = Utils.Type.SafeTableIndex(Table, "Items.Thing")
        print(ItemInTable)
    ```
    Output: `"Hey!"`

    ```lua
        local Table = {}

        -- SCENARIO 2 --
        --we're not setting the items table here
        
        local ItemInTable = Utils.TypeSafeTableIndex(Table, "Items.Thing")
        print(ItemInTable)
    ```
    Output: `nil`

    Here's what would happen if scenario 2 would've been done using normal indexing:
    ```lua
        local Table = {}

        -- SCENARIO 3 --
        --we're not setting the items table here

        local ItemInTable = Table.Items.Thing
        print(ItemInTable)
    ```
    Output: `ERROR in line 6: attempt to index 'nil' with "Items"`

    This, consequently, halts execution, and screws up scripts, without allowing for custom handling.

    This isn't needed for just one step indexing as it'll just be the same thing.

    ```lua
        local Table = {}

        -- SCENARIO 4 --
        --we're not setting the items table here

        local ItemInTable = Table.Items
        print(ItemInTable)
    ```
    Output: `nil`
]=]
function TypeUtils.SafeTableIndex<T>(TableToIndex: T & {}, Path: string): T & {}
    --gets all steps separately in a table to iterate over them
    local Steps = TypeUtils.SplitStringPath(Path)

    --set base item as the table itself
    local CurrentItem = TableToIndex

    --iterate over each step
    for _, Step in ipairs(Steps) do
        --if the current item is `nil`, halt and return `nil` to prevent halting thread execution
        if CurrentItem == nil then
            return
        end
        --try to index the next step in the current item
        CurrentItem = CurrentItem[Step]
        
        --i'm doing the check first just in case `TableToIndex` is `nil` for some reason
    end

    --this item supposedly was found, so return its value
    return CurrentItem
end

return TypeUtils
