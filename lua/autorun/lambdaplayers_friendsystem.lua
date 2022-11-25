local IsValid = IsValid
local table_Count = table.Count
local pairs = pairs
local RandomPairs = RandomPairs
local random = math.random
local table_Add = table.Add
local net = net
local player_GetAll = player.GetAll
local debugoverlay = debugoverlay
local dev = GetConVar( "developer" )
local uiscale = GetConVar( "lambdaplayers_uiscale" )

-- Friend System Convars

hook.Add( "LambdaOnConvarsCreated", "lambdafriendsystemConvars", function()

    CreateLambdaConvar( "lambdaplayers_friend_enabled", 1, true, false, false, "Enables the friend system that will allow Lambda Players to be friends with each other or with players and treat them as such", 0, 1, { name = "Enable Friend System", type = "Bool", category = "Friend System" } )
    CreateLambdaConvar( "lambdaplayers_friend_friendcount", 3, true, false, false, "How many friends a Lambda/Real Player can have", 1, 30, { name = "Friend Count", type = "Slider", decimals = 0, category = "Friend System" } )
    CreateLambdaConvar( "lambdaplayers_friend_friendchance", 5, true, false, false, "The chance a Lambda Player will spawn as someone's friend", 1, 100, { name = "Friend Chance", type = "Slider", decimals = 0, category = "Friend System" } )

end )


local function GetPlayers()
    local lambda = GetLambdaPlayers()
    local realplayers = player_GetAll()
    table_Add( lambda, realplayers )
    return lambda
end 

local function Initialize( self, wepent )
    if CLIENT then return end

    self.l_friends = {}

    -- If we are friends with ent
    function self:IsFriendsWith( ent )
        return IsValid( ent ) and IsValid( self.l_friends[ ent:GetCreationID() ] )
    end

    -- If we can be friends with ent
    function self:CanBeFriendsWith( ent )
        return ( ent.IsLambdaPlayer or ent:IsPlayer() ) and table_Count( self.l_friends ) < GetConVar( "lambdaplayers_friend_friendcount" ):GetInt() and table_Count( ent.l_friends ) < GetConVar( "lambdaplayers_friend_friendcount" ):GetInt() and !self:IsFriendsWith( ent )
    end
    
    function self:GetRandomFriend()
        for k, v in RandomPairs( self.l_friends ) do return v end
    end

    -- Add ent to our friends list
    function self:AddFriend( ent, forceadd )
        ent.l_friends = ent.l_friends or {} -- Make sure this table exists
        if self:IsFriendsWith( ent ) or !self:CanBeFriendsWith( ent ) and !forceadd or !GetConVar( "lambdaplayers_friend_enabled" ):GetBool() then return end
        
        self.l_friends[ ent:GetCreationID() ] = ent -- Add ent to our friends list
        ent.l_friends[ self:GetCreationID() ] = self -- Add ourselves to ent's friends list

        net.Start( "lambdaplayerfriendsystem_addfriend" )
        net.WriteUInt( self:GetCreationID(), 32 )
        net.WriteEntity( self )
        net.WriteEntity( ent )
        net.Broadcast()

        net.Start( "lambdaplayerfriendsystem_addfriend" )
        net.WriteUInt( ent:GetCreationID(), 32 )
        net.WriteEntity( ent )
        net.WriteEntity( self )
        net.Broadcast()

        -- Become friends with ent's friends
        for ID, entfriend in pairs( ent.l_friends ) do
            if entfriend == self or !self:CanBeFriendsWith( entfriend ) then continue end -- We can't be friends with em
            entfriend.l_friends = entfriend.l_friends or {}

            net.Start( "lambdaplayerfriendsystem_addfriend" )
            net.WriteUInt( self:GetCreationID(), 32 )
            net.WriteEntity( self )
            net.WriteEntity( entfriend)
            net.Broadcast()

            net.Start( "lambdaplayerfriendsystem_addfriend" )
            net.WriteUInt( entfriend:GetCreationID(), 32 )
            net.WriteEntity( entfriend )
            net.WriteEntity( self )
            net.Broadcast()


            self.l_friends[ entfriend:GetCreationID() ] = entfriend -- Add entfriend to our friends list
            entfriend.l_friends[ self:GetCreationID() ] = self -- Add ourselves to entfriend's friends list
        end
    end
    
    -- Remove ent from our friends list
    function self:RemoveFriend( ent )
        if !self:IsFriendsWith( ent ) then return end

        net.Start( "lambdaplayerfriendsystem_removefriend" )
        net.WriteUInt( self:GetCreationID(), 32 )
        net.WriteEntity( ent )
        net.Broadcast()

        net.Start( "lambdaplayerfriendsystem_removefriend" )
        net.WriteUInt( ent:GetCreationID(), 32 )
        net.WriteEntity( self )
        net.Broadcast()


        self.l_friends[ ent:GetCreationID() ] = nil -- Remove ent from our friend list
        ent.l_friends[ self:GetCreationID() ] = nil -- Remove ourselves from ent's friends list
    end


    if random( 0, 100 ) < GetConVar( "lambdaplayers_friend_friendchance" ):GetInt() then
        for k, v in RandomPairs( GetPlayers() ) do
            if v == self or self:IsFriendsWith( v ) or !self:CanBeFriendsWith( v ) then continue end
            self:AddFriend( v )
            break
        end
    end

end


local function Think( self, wepent )
    if CLIENT then return end

    if dev:GetBool() then
        for k, v in pairs( self.l_friends ) do
            debugoverlay.Line( self:WorldSpaceCenter(), v:WorldSpaceCenter(), 0, self:GetPlyColor():ToColor(), true )
        end
    end

end

local function OnInjured( self, info )
    return self:IsFriendsWith( info:GetAttacker() )
end

local function OnOtherInjured( self, victim, info, took )
    if !took or !self:IsFriendsWith( victim ) or info:GetAttacker() == self then print( self:Nick(), " FAILED ", !took , !self:IsFriendsWith( victim ) , info:GetAttacker() == self) return end
    print( self:Nick(), !LambdaIsValid( self:GetEnemy() ) , self:CanTarget( info:GetAttacker() ) , self:CanSee( info:GetAttacker() ))
    if !LambdaIsValid( self:GetEnemy() ) and self:CanTarget( info:GetAttacker() ) and self:CanSee( info:GetAttacker() ) then self:AttackTarget( info:GetAttacker() ) end
end


hook.Add( "LambdaOnOtherInjured", "lambdafriendsystemoninjured", OnOtherInjured )
hook.Add( "LambdaOnInjured", "lambdafriendsystemoninjured", OnInjured )
hook.Add( "LambdaOnThink", "lambdafriendsystemthink", Think )
-- Initialize stuff
hook.Add( "LambdaOnInitialize", "lambdafriendsysteminit", Initialize )

if SERVER then

    util.AddNetworkString( "lambdaplayerfriendsystem_addfriend" )
    util.AddNetworkString( "lambdaplayerfriendsystem_removefriend" )

    local function OnRemove( self )
        for ID, friend in pairs( self.l_friends ) do
            self:RemoveFriend( friend )
        end
    end

    local function CanTarget( self, target ) -- Do not attack friends
        return self:IsFriendsWith( target ) 
    end

    hook.Add( "LambdaOnRemove", "lambdafriendsystemOnRemove", OnRemove )
    hook.Add( "LambdaCanTarget", "lambdafriendsystemtarget",  CanTarget )

elseif CLIENT then
    local AddHalo = halo.Add
    local clientcolor = Color( 255, 145, 0 )
    local tracetable = {}
    local Trace = util.TraceLine
    local DrawText = draw.DrawText
    local uiscale = GetConVar( "lambdaplayers_uiscale" )

    local function UpdateFont()
        surface.CreateFont( "lambdaplayers_friendfont", {
            font = "ChatFont",
            size = LambdaScreenScale( 7 + uiscale:GetFloat() ),
            weight = 0,
            shadow = true
        })
    end
    UpdateFont()
    cvars.AddChangeCallback( "lambdaplayers_uiscale", UpdateFont, "lambdafriendsystemfonts" )

    hook.Add( "PreDrawHalos", "lambdafriendsystemhalos", function()
        local friends = LocalPlayer().l_friends
        if friends then
            for k, v in pairs( friends ) do
                if !LambdaIsValid( v ) then continue end
                AddHalo( { v }, clientcolor, 3, 3, 1, true, false )
            end
        end
    end )

    hook.Add( "HUDPaint", "lambdafriendsystemhud", function()
        local friends = LocalPlayer().l_friends

        if friends then
            
            for k, v in pairs( friends ) do
                if !LambdaIsValid( v ) then continue end

                tracetable.start = LocalPlayer():EyePos()
                tracetable.endpos = v:WorldSpaceCenter()
                tracetable.filter = LocalPlayer()
                local result = Trace( tracetable )

                if result.Entity != v then continue end
                local vectoscreen = ( v:GetPos() + v:OBBCenter() * 2.5 ):ToScreen()
                if !vectoscreen.visible then continue end

                DrawText( "Friend", "lambdaplayers_friendfont", vectoscreen.x, vectoscreen.y, clientcolor, TEXT_ALIGN_CENTER )
            end

        end


        local sw, sh = ScrW(), ScrH()
        local traceent = LocalPlayer():GetEyeTrace().Entity

        if LambdaIsValid( traceent ) and traceent.IsLambdaPlayer then
            local name = traceent:GetLambdaName()
            local buildstring = "Friends With: "
            local friends = traceent.l_friends

            if friends then
                local count = 0
                local others = 0
                for k, v in pairs( friends ) do
                    count = count + 1

                    if count > 3 then others = others + 1 continue end

                    buildstring = buildstring .. v:Nick() .. ( table_Count( friends ) > count and ", " or "" )
                end
                buildstring = others > 0 and buildstring .. " and " .. ( others ) .. ( others > 1 and " others" or " other") or buildstring
                DrawText( buildstring, "lambdaplayers_displayname", ( sw / 2 ), ( sh / 1.77 ) + LambdaScreenScale( 1 + uiscale:GetFloat() ), clientcolor, TEXT_ALIGN_CENTER)
            end
        end

    end )

    net.Receive( "lambdaplayerfriendsystem_addfriend", function() 
        local id = net.ReadUInt( 32 )
        local lambda = net.ReadEntity()
        local receiver = net.ReadEntity()
        receiver.l_friends = receiver.l_friends or {}
        receiver.l_friends[ id ] = lambda
    end )

    net.Receive( "lambdaplayerfriendsystem_removefriend", function() 
        local id = net.ReadUInt( 32 )
        local receiver = net.ReadEntity()

        if !receiver.l_friends then return end
        receiver.l_friends[ id ] = nil
    end )

    
end