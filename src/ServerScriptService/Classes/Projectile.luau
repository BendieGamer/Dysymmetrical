local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Hitbox = require(script.Parent.Hitbox)
local Types = require(ReplicatedStorage.Classes.Types)
local Utils = require(ReplicatedStorage.Modules.Utils)

local Projectile = {}

local DefaultConfig: Types.Projectile = {
    Speed = 50,
    FinalRotation = CFrame.new(),
    Lifetime = 5,
    ThrowType = "Forward",
    DestroyOnCollision = false,
}

function Projectile.New(ProjectileSettings: Types.Projectile): Types.ProjectileDetails
    --sanity checks for badly written settings
    if not ProjectileSettings then
        warn("[Projectile.New()] No projectile settings specified!\n", debug.traceback())
        return {}
    end
    --checking for all important fields
    do
        local MissingFields = {}
        --placing all of them in a table for more verbose logging
        for _, FieldName in {"SourcePlayer", "Model", "StartingCFrame", "HitboxSettings"} do
            if ProjectileSettings[FieldName] == nil then
                table.insert(MissingFields, FieldName)
            end
        end
        --if there are any missing, concatenate every missing field's name to the error message and `warn()` it
        if #MissingFields > 0 then
            local ErrorLog = "[Projectile.New()] Projectile settings missing crucial fields! ("
            for Index, Field in MissingFields do
                ErrorLog = ErrorLog..Field
                if Index < #MissingFields then
                    ErrorLog = ErrorLog..", "
                else
                    ErrorLog = ErrorLog..")"
                end
            end

            warn(ErrorLog.."\n", debug.traceback())

            return {}
        end
    end

    --place all other missing values
    Utils.Type.DeepTableWrite(ProjectileSettings, DefaultConfig)

    --projectile-enforced hitbox settings
    ProjectileSettings.HitboxSettings.IsProjectile = true
    ProjectileSettings.HitboxSettings.PredictVelocity = false
    ProjectileSettings.HitboxSettings.HitMultiple = if ProjectileSettings.HitboxSettings.HitMultiple ~= nil then ProjectileSettings.HitboxSettings.HitMultiple else true
    ProjectileSettings.HitboxSettings.Time = ProjectileSettings.Lifetime

    --if this becomes true, the projectile will stop its execution
    --only changeable through `ProjectileInstance.Destroy()`
    local ShouldCancel = false

    --define da thing
    local ProjectileInstance: Types.ProjectileDetails = {
        Model = ProjectileSettings.Model:Clone(),
        Hitbox = Hitbox.New(ProjectileSettings.SourcePlayer, ProjectileSettings.HitboxSettings),
        Destroyed = false,
        Destroy = function(self: Types.ProjectileDetails)
            if self.Destroyed then
                return
            end
            self.Destroyed = true

            if ProjectileSettings.OnDestroy then
                ProjectileSettings:OnDestroy(self)
            end
            ShouldCancel = true
            self.Model:Destroy()
            self.Hitbox:Cancel()
        end,
    }

    --clone into workspace
    --if a map is available, it'll be in its `InGame` folder
    --if not, just place it in `TempObjectFolders`
    ProjectileInstance.Model.Parent = workspace:FindFirstChild("Map") and workspace.Map.InGame or workspace.TempObjectFolders

    local IsModel: boolean = ProjectileInstance.Model:IsA("Model")

    --look up the cframe based on what the projectile's model is
    ProjectileSettings.HitboxSettings.CFrame = ProjectileSettings.HitboxSettings.CFrame or function(): CFrame
        if IsModel then
            if ProjectileInstance.Model.PrimaryPart ~= nil then
                return ProjectileInstance.Model.PrimaryPart.CFrame
            else
                return ProjectileInstance.Model.WorldPivot
            end
        else
            return ProjectileInstance.Model.CFrame
        end
    end

    --aim to where the mouse is pointing if needed
    if ProjectileSettings.ThrowType == "Mouse" then
        local Direction = Utils.Player.GetPlayerMousePosition(ProjectileSettings.SourcePlayer, false)
        ProjectileSettings.StartingCFrame = CFrame.lookAt(ProjectileSettings.StartingCFrame.Position, Direction)
    end

    --move to starting CFrame
    if IsModel then
        ProjectileInstance.Model:PivotTo(ProjectileSettings.StartingCFrame)
    else
        ProjectileInstance.Model.CFrame = ProjectileSettings.StartingCFrame
    end

    --make a delay to destroy everything after this projectile's lifetime
    task.delay(ProjectileSettings.Lifetime, ProjectileInstance.Destroy, ProjectileInstance)

    --get the goal, add the final rotation if existent, and tween the projectile
    local Goal = ProjectileSettings.StartingCFrame * CFrame.new(0, 0, -ProjectileSettings.Speed * ProjectileSettings.Lifetime)
    if ProjectileSettings.FinalRotation then
        Goal *= ProjectileSettings.FinalRotation
    end
    ProjectileInstance.Tween = TweenService:Create(ProjectileInstance.Model:IsA("Model") and ProjectileInstance.Model.WorldPivot or ProjectileInstance.Model, TweenInfo.new(ProjectileSettings.Lifetime), {
        CFrame = Goal,
    })
    ProjectileInstance.Tween:Play()

    --if this projectile is set to be destroyed on collision, schedule a loop that checks for collisions using casts
    if ProjectileSettings.DestroyOnCollision then
        --defer to avoid scheduling issues
        task.defer(function()
            --create params for casting
            local DestroyParams = RaycastParams.new()
            DestroyParams.FilterType = Enum.RaycastFilterType.Exclude
            DestroyParams.FilterDescendantsInstances = {ProjectileSettings.SourcePlayer.Character}
            DestroyParams.RespectCanCollide = true

            --getting necessary stuffs
            local Model: BasePart | Model = ProjectileInstance.Model
            local CollisionBox: BasePart? = Model:FindFirstChild("CollisionBox")
            local Primary: BasePart? = IsModel and Model.PrimaryPart

            --if the hitbox is cancelled or the model isn't there, stop
            while not (ShouldCancel or not ProjectileInstance.Model) do
                --find anything right ahead of the projectile with a cast
                --if the collision box isn't available, it'll fall back to block cast
                local Touching = if CollisionBox ~= nil then
                    workspace:Shapecast(CollisionBox, CollisionBox.CFrame.LookVector, DestroyParams) else
                    workspace:Blockcast(
                        IsModel and (Primary and Primary.Position or Primary.WorldPivot.Position) or Model.Position,
                        IsModel and Model:GetBoundingBox() or Model.Size,
                        IsModel and (Primary and Primary.CFrame.LookVector or Model.WorldPivot.LookVector) or Model.CFrame.LookVector
                    )

                --if the cast returns a hit, call `Projectile.OnHitDestroy()` and destroy the instance
                if Touching and Touching.Instance then
                    local PreventDestruction = if ProjectileSettings.OnHitDestroy then ProjectileSettings:OnHitDestroy(ProjectileInstance) == "PreventDestruction" else false
                    
                    if not PreventDestruction then
                        ProjectileInstance:Destroy()
                    end
                    
                    break
                end

                task.wait()
            end
        end)
    end

    return ProjectileInstance
end

return Projectile
