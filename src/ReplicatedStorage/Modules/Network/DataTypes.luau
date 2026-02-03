local HttpService = game:GetService("HttpService")

local BufferTag = table.freeze({
    boolean = 1,
    Int8 = 2,
    Int16 = 3,
    Int32 = 4,
    Float32 = 5,
    Float64 = 6,
    Vector3 = 7,
    JSON = 8,
    buffer = 9,
    string = 10,
    CFrame = 11,
    Vector2 = 12,
    Color3 = 13,
    UDim2 = 14,
    BrickColor = 15,
    Rect = 16,
    NumberRange = 17,
    UDim = 18,
    DateTime = 19,
    ColorSequence = 20,
    NumberSequence = 21,
})

return {
    Enum = BufferTag,

    Behaviour = table.freeze({
        --boolean
        {
            Encode = function(ValueToCompress: boolean): buffer
                local b = buffer.create(2) --1 byte for id + 1 byte for value (0 or 1)
                buffer.writeu8(b, 0, BufferTag.boolean)
                buffer.writeu8(b, 1, ValueToCompress and 1 or 0) --
                return b
            end,
            Decode = function(Buffer: buffer): boolean
                local val = buffer.readu8(Buffer, 1)
                return val == 1 --as in binary code, 1 is true, 0 is false
            end,
        },
        --int8
        {
            Encode = function(ValueToCompress: number): buffer
                local b = buffer.create(2) --1 byte for id + 1 for an int8
                buffer.writeu8(b, 0, BufferTag.Int8)
                buffer.writei8(b, 1, ValueToCompress)
                return b
            end,
            Decode = function(Buffer: buffer): number
                return buffer.readi8(Buffer, 1)
            end,
        },
        --int16
        {
            Encode = function(ValueToCompress: number): buffer
                local b = buffer.create(3) --1 byte for id + 2 for an int16
                buffer.writeu8(b, 0, BufferTag.Int16)
                buffer.writei16(b, 1, ValueToCompress)
                return b
            end,
            Decode = function(Buffer: buffer): number
                return buffer.readi16(Buffer, 1)
            end,
        },
        --int32
        {
            Encode = function(ValueToCompress: number): buffer
                local b = buffer.create(5) --1 byte for id + 4 for an int32
                buffer.writeu8(b, 0, BufferTag.Int32)
                buffer.writei32(b, 1, ValueToCompress)
                return b
            end,
            Decode = function(Buffer: buffer): number
                return buffer.readi32(Buffer, 1)
            end,
        },
        --float32
        {
            Encode = function(ValueToCompress: number): buffer
                local b = buffer.create(5) --1 byte for id + 4 for a float32
                buffer.writeu8(b, 0, BufferTag.Float32)
                buffer.writef32(b, 1, ValueToCompress)
                return b
            end,
            Decode = function(Buffer: buffer): number
                return buffer.readf32(Buffer, 1)
            end,
        },
        --float64
        {
            Encode = function(ValueToCompress: number): buffer
                local b = buffer.create(9) --1 byte for id + 8 for a float64
                buffer.writeu8(b, 0, BufferTag.Float64)
                buffer.writef64(b, 1, ValueToCompress)
                return b
            end,
            Decode = function(Buffer: buffer): number
                return buffer.readf64(Buffer, 1)
            end,
        },
        --vector3
        {
            Encode = function(ValueToCompress: Vector3): buffer
                local b = buffer.create(13) --1 byte for id + 12 for a vector3 (4 bytes per float32 / vector component)
                buffer.writeu8(b, 0, BufferTag.Vector3)
                buffer.writef32(b, 1, ValueToCompress.X)
                buffer.writef32(b, 5, ValueToCompress.Y)
                buffer.writef32(b, 9, ValueToCompress.Z)
                return b
            end,
            Decode = function(Buffer: buffer): Vector3
                return Vector3.new(
                    buffer.readf32(Buffer, 1),
                    buffer.readf32(Buffer, 5),
                    buffer.readf32(Buffer, 9)
                )
            end,
        },
        --JSON
        {
            Encode = function(ValueToCompress: any): buffer
                local encoded = HttpService:JSONEncode(ValueToCompress)
                if encoded == "null" then
                    if workspace:GetAttribute("DebugAllowed") == true then
                        warn(`[DysNetworking:_CompressValue()]: Data Type {typeof(ValueToCompress)} cannot be converted to JSON.`)
                    end
                    return
                end
                
                local len = #encoded
                local b = buffer.create(len + 1) -- 1 byte for id + length of JSON string
                buffer.writeu8(b, 0, BufferTag.JSON)
                buffer.writestring(b, 1, encoded)
                return b
            end,
            Decode = function(Buffer: buffer): any
                local content = buffer.readstring(Buffer, 1, buffer.len(Buffer) - 1)
                return HttpService:JSONDecode(content)
            end,
        },
        --buffer
        {
            Encode = function(ValueToCompress: buffer): buffer
                local Length = buffer.len(ValueToCompress :: any)
                local b = buffer.create(Length + 1)
                buffer.writeu8(b, 0, BufferTag.buffer)
                buffer.copy(b, 1, ValueToCompress :: any, 0, Length)
                return b
            end,
            Decode = function(Buffer: buffer): buffer
                local Length = buffer.len(Buffer) - 1
                local b = buffer.create(Length)
                --copy everything over except for the tag to maintain order
                buffer.copy(b, 0, Buffer, 1, Length)
                return b
            end,
        },
        --string
        {
            Encode = function(ValueToCompress: string): buffer
                local len = #ValueToCompress
                local b = buffer.create(5 + len)  --1 byte for id + 4 bytes for an unsigned int32 (length) + as many bytes as needed
                buffer.writeu8(b, 0, BufferTag.string)
                buffer.writeu32(b, 1, len)
                buffer.writestring(b, 5, ValueToCompress)
                return b
            end,
            Decode = function(Buffer: buffer): string
                --get the length of the string
                local len = buffer.readu32(Buffer, 1)
                --read the entirety of it
                return buffer.readstring(Buffer, 5, len)
            end,
        },
        --cframe
        {
            Encode = function(ValueToCompress: CFrame): buffer
                local b = buffer.create(49) --1 byte for id + 48 bytes for the cframe (4 bytes per component, 12 components, 12 * 4 = 48 bytes)
                buffer.writeu8(b, 0, BufferTag.CFrame)
                local Components = table.pack(ValueToCompress:GetComponents())

                local Offset = 1
                for _, Component in ipairs(Components) do
                    buffer.writef32(b, Offset, Component)
                    Offset += 4
                end
                
                return b
            end,
            Decode = function(Buffer: buffer): CFrame
                local Components = {}
                --read every component (reminder that 12 * 4 is 48 so we read starting from 1 all the way up to 45, which is the 1st byte of the last 4-byte component)
                for Index = 1, 45, 4 do
                    table.insert(Components, buffer.readf32(Buffer, Index))
                end
                --then unpack all of the components into the cframe
                return CFrame.new(table.unpack(Components))
            end,
        },
        --vector2
        {
            Encode = function(ValueToCompress: Vector2): buffer
                local b = buffer.create(9) --1 byte for id + 8 bytes for components (4 bytes per float32, 2 float32s)
                buffer.writeu8(b, 0, BufferTag.Vector2)
                buffer.writef32(b, 1, ValueToCompress.X)
                buffer.writef32(b, 5, ValueToCompress.Y)
                return b
            end,
            Decode = function(Buffer: buffer): Vector2
                return Vector2.new(
                    buffer.readf32(Buffer, 1),
                    buffer.readf32(Buffer, 5)
                )
            end,
        },
        --color3
        {
            Encode = function(ValueToCompress: Color3): buffer
                local b = buffer.create(13) ----1 byte for id + 12 bytes for components (4 bytes per float32, 3 float32s)
                buffer.writeu8(b, 0, BufferTag.Color3)
                buffer.writef32(b, 1, ValueToCompress.R)
                buffer.writef32(b, 5, ValueToCompress.G)
                buffer.writef32(b, 9, ValueToCompress.B)
                return b
            end,
            Decode = function(Buffer: buffer): Color3
                return Color3.new(
                    buffer.readf32(Buffer, 1),
                    buffer.readf32(Buffer, 5),
                    buffer.readf32(Buffer, 9)
                )
            end,
        },
        --udim2
        {
            Encode = function(ValueToCompress: UDim2): buffer
                local b = buffer.create(17)  --1 byte for id + 16 bytes for all components (offsets are int32s, scales are float32s, 4 bytes each)
                buffer.writeu8(b, 0, BufferTag.UDim2)
                buffer.writef32(b, 1, ValueToCompress.X.Scale)
                buffer.writei32(b, 5, ValueToCompress.X.Offset)
                buffer.writef32(b, 9, ValueToCompress.Y.Scale)
                buffer.writei32(b, 13, ValueToCompress.Y.Offset)
                return b
            end,
            Decode = function(Buffer: buffer): UDim2
                return UDim2.new(
                    buffer.readf32(Buffer, 1), --x scale
                    buffer.readi32(Buffer, 5), --x offset
                    buffer.readf32(Buffer, 9), --y scale
                    buffer.readi32(Buffer, 13) --y offset
                )
            end,
        },
        --brickcolor
        {
            Encode = function(ValueToCompress: BrickColor): buffer
                local b = buffer.create(3) --1 byte for id + 2 bytes for an unsigned int16 since they're always int ids and they don't go that far
                buffer.writeu8(b, 0, BufferTag.BrickColor)
                buffer.writeu16(b, 1, ValueToCompress.Number)
                return b
            end,
            Decode = function(Buffer: buffer): BrickColor
                return BrickColor.new(buffer.readu16(Buffer, 1))
            end,
        },
        --rect
        {
            Encode = function(ValueToCompress: Rect): buffer
                local b = buffer.create(17) --1 byte for id + 16 bytes for 2 vector2s (4 bytes per float32, 4 float32s)
                buffer.writeu8(b, 0, BufferTag.Rect)
                buffer.writef32(b, 1, ValueToCompress.Min.X)
                buffer.writef32(b, 5, ValueToCompress.Min.Y)
                buffer.writef32(b, 9, ValueToCompress.Max.X)
                buffer.writef32(b, 13, ValueToCompress.Max.Y)
                return b
            end,
            Decode = function(Buffer: buffer): Rect
                return Rect.new(
                    buffer.readf32(Buffer, 1), --min x
                    buffer.readf32(Buffer, 5), --min y
                    buffer.readf32(Buffer, 9), --max x
                    buffer.readf32(Buffer, 13) --max y
                )
            end,
        },
        --numberrange
        {
            Encode = function(ValueToCompress: NumberRange): buffer
                local b = buffer.create(9) -- 1 byte for id + 8 bytes (2 floats)
                buffer.writeu8(b, 0, BufferTag.NumberRange)
                buffer.writef32(b, 1, ValueToCompress.Min)
                buffer.writef32(b, 5, ValueToCompress.Max)
                return b
            end,
            Decode = function(Buffer: buffer): NumberRange
                return NumberRange.new(
                    buffer.readf32(Buffer, 1),
                    buffer.readf32(Buffer, 5)
                )
            end,
        },
        --udim
        {
            Encode = function(ValueToCompress: UDim): buffer
                local b = buffer.create(9) -- 1 byte id + 8 bytes (float + int)
                buffer.writeu8(b, 0, BufferTag.UDim)
                buffer.writef32(b, 1, ValueToCompress.Scale)
                buffer.writei32(b, 5, ValueToCompress.Offset)
                return b
            end,
            Decode = function(Buffer: buffer): UDim
                return UDim.new(
                    buffer.readf32(Buffer, 1),
                    buffer.readi32(Buffer, 5)
                )
            end,
        },
        --datetime
        {
            Encode = function(ValueToCompress: DateTime): buffer
                local b = buffer.create(9) -- 1 byte id + 8 bytes (float64)
                buffer.writeu8(b, 0, BufferTag.DateTime)
                buffer.writef64(b, 1, ValueToCompress.UnixTimestamp)
                return b
            end,
            Decode = function(Buffer: buffer): DateTime
                return DateTime.fromUnixTimestamp(buffer.readf64(Buffer, 1))
            end,
        },
        --colorsequence
        {
            Encode = function(ValueToCompress: ColorSequence): buffer
                local Keypoints = ValueToCompress.Keypoints
                local Count = #Keypoints
                local Offset = 2
                -- 1 byte for id + 1 byte for count + (16 bytes per keypoint * count, 4 bytes per keypoint component, 4 components per keypoint)
                local b = buffer.create(Offset + (Count * 16))
                
                buffer.writeu8(b, 0, BufferTag.ColorSequence)
                buffer.writeu8(b, 1, Count)
                
                for _, Keypoint in ipairs(Keypoints) do
                    buffer.writef32(b, Offset, Keypoint.Time)
                    Offset += 4
                    for _, ColorValue in {"R", "G", "B"} do
                        buffer.writef32(b, Offset, Keypoint.Value[ColorValue])
                        Offset += 4
                    end
                end
                return b
            end,
            Decode = function(Buffer: buffer): ColorSequence
                local Count = buffer.readu8(Buffer, 1)
                local Keypoints = table.create(Count)
                local Offset = 2

                for _ = 1, Count do
                    local Time = buffer.readf32(Buffer, Offset)
                    Offset += 4

                    local ColorValues = {}
                    for _ = 1, 3 do
                        table.insert(ColorValues, buffer.readf32(Buffer, Offset))
                        Offset += 4
                    end
                    table.insert(Keypoints, ColorSequenceKeypoint.new(Time, Color3.new(table.unpack(ColorValues))))
                end
                
                return ColorSequence.new(Keypoints)
            end,
        },
        --numbersequence
        {
            Encode = function(ValueToCompress: NumberSequence): buffer
                local Keypoints = ValueToCompress.Keypoints
                local Count = #Keypoints
                -- 1 byte id + 1 byte count + (12 bytes per keypoint * count)
                -- 12 bytes = Time(4) + Value(4) + Envelope(4)
                local b = buffer.create(2 + (Count * 12))
                
                buffer.writeu8(b, 0, BufferTag.NumberSequence)
                buffer.writeu8(b, 1, Count)
                
                local Offset = 2
                for _, Kp in ipairs(Keypoints) do
                    buffer.writef32(b, Offset, Kp.Time)
                    buffer.writef32(b, Offset + 4, Kp.Value)
                    buffer.writef32(b, Offset + 8, Kp.Envelope)
                    Offset += 12
                end
                return b
            end,
            Decode = function(Buffer: buffer): NumberSequence
                local Count = buffer.readu8(Buffer, 1)
                local Keypoints = table.create(Count)
                local Offset = 2
                
                for _ = 1, Count do
                    local Time = buffer.readf32(Buffer, Offset)
                    local Value = buffer.readf32(Buffer, Offset + 4)
                    local Envelope = buffer.readf32(Buffer, Offset + 8)
                    
                    table.insert(Keypoints, NumberSequenceKeypoint.new(Time, Value, Envelope))
                    Offset += 12
                end
                
                return NumberSequence.new(Keypoints)
            end,
        },
    }),
} :: {
    Enum: typeof(BufferTag),
    Behaviour: {[number]: {
        Encode: (ValueToCompress: any) -> buffer,
        Decode: (Buffer: buffer) -> any,
    }}
}