/*#############################################################################
###         CORE FILE - DONT TOUCH IT OR YOU WILL LOSE ANY SUPPORT!
#############################################################################*/
local version = 0.2
if PlainLIB && PlainLIB.Version > version then return end
PlainLIB = {}
PlainLIB.Version = version
PlainLIB.Prefix = "[PlainLIB] "
local string = string
local table,math = table,math
local unpack = unpack
local RunConsoleCommand = RunConsoleCommand
local pairs,ipairs = pairs,ipairs
local file = file
local TraceLine = util.TraceLine
local hooks = hook.GetTable()
hook.Add("Initialize", "PlainLIB.Initialize", function()
    hooks = hook.GetTable()
end)
-- Version command
concommand.Add( "plainlib", function(ply, cmd, args)
    local arg = args[1]
    local name = "PlainLIB"
    if #args < 1 then print("["..name.."] LUA Script Library for Gmod by .delay") end
    if arg == "version" then print("v"..PlainLIB.Version) end
    
end)
function PlainLIB:CutStr(txt,maxlen)
    local len = string.len(txt)
    if len > maxlen then
        return string.sub( txt, 1, maxlen )..".."
    --elseif len == maxlen then
    --    return txt
    else
        return txt
    end
end
function PlainLIB:UpString(str)
    return string.upper(string.sub(str, 1, 1))..""..string.sub(str, 2)
end
function PlainLIB:IsSandbox()
    if engine.ActiveGamemode()=="sandbox" then return true else return false end
end
function PlainLIB:IsDarkRP()
    if engine.ActiveGamemode()=="darkrp" then return true else return false end
end
function PlainLIB:IsTTT()
    if engine.ActiveGamemode()=="terrortown" then return true else return false end
end
function PlainLIB:IsGM(mod)
    if engine.ActiveGamemode()==mod then return true else return false end
end
-- Check adminmod
function PlainLIB:AdminMod()
    -- Ulx check
    if hooks.PhysgunPickup.ulxPlayerPickup then
        return true, "ulx"
    end
    
    return false
end
-- Get map table
PlainLIB.Maps = {}
for _, map in ipairs(file.Find( "maps/*.bsp", "GAME" )) do table.insert( PlainLIB.Maps, map:sub( 1, -5 ):lower() ) end
table.sort( PlainLIB.Maps )
-- Loop function for all players
function PlainLIB:LoopPlayers(args)
    args = unpack(args)
    if SERVER then
        for k,v in pairs( player.GetAll() ) do
            
        end
    elseif CLIENT then
        for k,v in pairs( player.GetAll() ) do
            RunConsoleCommand( args, v )
        end
    end
end
-- In sight check
function PlainLIB:InSight(ply,targ)
    local ppos,tpos = ply:GetShootPos(),targ:GetPos()
    local directionAng = math.pi / 8
    local aimVec = ply:GetAimVector()
    local entVec = tpos - ppos
    local dot = aimVec:Dot( entVec ) / entVec:Length()
    --print( dot < directionAng )
    -- Direction check
    if dot > directionAng then
    --if aimVec:DotProduct( ( entVec - ply:GetPos() + Vector( 70 ) ):Normalize() ) < 0.95 then
        local trace = { start=ppos, endpos=targ:GetShootPos(), filter=ply, mask=MASK_OPAQUE_AND_NPCS }
        local tr = TraceLine( trace )
        if tr.Hit && tr.Entity != targ then
            trace.endpos = tpos+Vector(0,0,2)
            tr = TraceLine( trace )
            if tr.Hit && tr.Entity != targ then
                trace.endpos = tpos+Vector(0,0,40)
                tr = TraceLine( trace )
                if tr.Hit && tr.Entity != targ then
                    return false
                end
            end
        end
        return true
    end
    return false
end
-- Calc Health
PlainLIB.Health = {}
function PlainLIB:GetHealth(ply)
    local starthealth = 100
    if GAMEMODE.Config && GAMEMODE.Config.startinghealth then starthealth = GAMEMODE.Config.startinghealth end
    PlainLIB.Health[ply:EntIndex()] = PlainLIB.Health[ply:EntIndex()] or 0
    local TargHealth = ply:Health()
    local HealthTarg = PlainLIB.Health[ply:EntIndex()]
    HealthTarg = math.min(100, (HealthTarg == TargHealth and HealthTarg) or Lerp(0.05, HealthTarg, TargHealth))
    local DrawHealth = math.Min(HealthTarg / starthealth, 1)
    PlainLIB.Health[ply:EntIndex()] = HealthTarg    
    return DrawHealth
end


if SERVER then
    -- Remote commands
    util.AddNetworkString( "PlainLIB.SVCommand" )
    net.Receive( "PlainLIB.SVCommand", function( len, ply )
        if ply:IsAdmin() then
            local args = net.ReadTable()
            local cmd = ""
            for k,v in pairs( args ) do cmd = cmd..v.." " end
            print( PlainLIB.Prefix.."RemoteCommand from "..ply:Nick().." -> "..cmd )
            game.ConsoleCommand( cmd.."\n" )
        end
    end)
    -- Data sync functions for broken stuff in gamemodes
    util.AddNetworkString("PlainLIB.Sync")
    function PlainLIB:SyncData()
        net.Start("PlainLIB.Sync")
            if PlainLIB:IsTTT() then
                net.WriteFloat( GetGlobalFloat("ttt_round_end", 0) )
                net.WriteInt( GetGlobalInt("ttt_rounds_left", 6) , 32 )
            end
        net.Broadcast()
    end
    -- TTT time sync hooks
    hook.Add("TTTPrepareRound", "PlainSB.TTTPrepareRound", function() PlainLIB:SyncData() end)
    hook.Add("TTTBeginRound", "PlainSB.TTTBeginRound", function() PlainLIB:SyncData() end)
    hook.Add("TTTEndRound", "PlainSB.TTTEndRound", function() PlainLIB:SyncData() end)
    
elseif CLIENT then
    local surface = surface
    local function loadFonts()
        surface.CreateFont("PlainLIB.Default", {
        size = 11,
        weight = 500,
        antialias = false,
        shadow = false,
        font = "Default"})
    end
    loadFonts()
    hook.Add("Initialize", "PlainLIB.LoadFonts", loadFonts)
    -- Remote commands
    function PlainLIB:SVCommand( args )
        if LocalPlayer():IsAdmin() then
            net.Start( "PlainLIB.SVCommand" )
                net.WriteTable( args )
            net.SendToServer()
        end
    end
    -- Sny data receiver
    net.Receive("PlainLIB.Sync", function(len,ply)
        if PlainLIB:IsTTT() then
            SetGlobalFloat("ttt_round_end", net.ReadFloat())
            SetGlobalInt("ttt_rounds_left", net.ReadInt(32))
        end
	end)
    --hook.Add("InitPostEntity", "PlainLIB.LoadFonts", loadFonts)
    function PlainLIB:StrRequest(title,desc,deftxt,args)
        deftxt = deftxt or ""
        Derma_StringRequest(title,desc,deftxt,
            function(text) -- Confirm func
                --print( unpack(args) )
                args[#args+1] = text
                RunConsoleCommand( unpack(args) )
                return true,text
            end,            
            function() -- Abort func
                return false
            end,
            "OK", "Cancel"
        )
    end
    PlainLIB.Font1 = "HudHintTextLarge"
    PlainLIB.Font2 = "Trebuchet18"
    PlainLIB.Texture = Material( "scoreboard/psb_texture.png", "noclamp smooth" )
    PlainLIB.SoundHover = "gui/ooweep.wav"
    PlainLIB.SoundClick = "gui/beep4.wav"
    function PlainLIB:DrawIcon(icon,x,y,col,glow)
        local col = col or Color(255,255,255,255)
        local alpha = col.a
        if glow && glow=="nobg" then
        elseif glow then
            alpha = 255-glow*255
            draw.RoundedBox( 4, x, y-2, 20, 20, PlainHUD.ColorMain)
        else
            draw.RoundedBox( 4, x, y-2, 20, 20, PlainHUD.ColorMain)
        end
        surface.SetDrawColor( col.r, col.g, col.b, alpha )
        surface.SetMaterial( Material( icon ) )
        surface.DrawTexturedRect( x+2.5, y-0, 16, 16 )
    end
    function PlainLIB:Draw3D2D(pos,ang,scale,func)
        if !func then return end
        if ang == nil then
            ang = RenderAngles() -- Calc player view
            ang:RotateAroundAxis(ang:Forward(), 90)
            ang:RotateAroundAxis(ang:Right(), 90)
        end
        cam.Start3D()
            cam.Start3D2D( pos, ang, scale )
                func()
            cam.End3D2D()
        cam.End3D()
    end
    function PlainLIB:DrawAlignText(text,font,parent,col,align)
        local wide,tall = parent:GetWide(),parent:GetTall()
        surface.SetFont( font )
        local tw,th = surface.GetTextSize( text )
        local x,y = wide/2, tall/2-th/2
        if align==TEXT_ALIGN_LEFT then
            x,y = 10, tall/2-th/2
        elseif align==TEXT_ALIGN_RIGHT then
            x,y = wide-10, tall/2-th/2
        end
        draw.DrawText(text,font,x,y,col,align)
    end
    function PlainLIB:DrawTextBox(text,icon,font,col1,col2,col3,x,y)
        surface.SetFont( font )
        local w,h = surface.GetTextSize( text )
        h = 20
        draw.RoundedBox( 4, x, y, w+32, h, col1)
        PlainLIB:DrawIcon(icon,x+4, y+2,col3,"nobg")
        draw.SimpleText( text, font, x+26+1, y+2, Color(0,0,0,120) )
        draw.SimpleText( text, font, x+26, y+1, col2 )
    end
    function PlainLIB:Button(parent,desc,func)
        local Btn = vgui.Create("DButton", parent)
        Btn:SetFont(PlainLIB.Font1)
        Btn:SetText(desc)
        surface.SetFont(PlainLIB.Font1)
        local dw,dh = surface.GetTextSize(desc)
        Btn:SetWide(dw+40)
        local btnA = 220
        Btn.Paint = function(btn)
            local border = 1
            draw.RoundedBox( 0, 0, 0, btn:GetWide(), btn:GetTall(), Color(0,0,0,255))
            local mat = PlainLIB.Texture
            if !string.match(tostring(mat),"___error") then
                surface.SetDrawColor( 62, 62, 62, btnA )
                surface.SetMaterial( mat )
                surface.DrawTexturedRect( border, border, btn:GetWide()-border*2, btn:GetTall()-border*2 )
            else
                draw.RoundedBox( 0, border, border, btn:GetWide()-border*2, btn:GetTall()-border*2, Color( 62, 62, 62, btnA ))
            end
        end
        Btn.OnCursorEntered = function()
            surface.PlaySound(PlainLIB.SoundHover)
            btnA = 255
            Btn.PinfoActive = true
        end
        Btn.OnCursorExited = function()
            btnA = 220
            Btn.PinfoActive = false
        end
        Btn.DoClick = function()
            surface.PlaySound(PlainLIB.SoundClick)
            if func then func() end
        end
        return Btn
    end
    function PlainLIB:TextEntry(parent, desc, func)
        local TE = vgui.Create( "DTextEntry", parent )
        TE:SetText( desc )
        TE.OnEnter = function()
            surface.PlaySound(PlainLIB.SoundClick)
            if func then func() end
        end
        return TE
    end
    local col1 = Color( 102,102,102, 230 )
    local col2 = Color( 51, 51, 51, 255 )
    local col3 = Color( 82, 82, 82, 255 )
    local col4 = Color(0,0,0,200)
    local col5 = Color(255,255,255,200)
    function PlainLIB:Window(name,w,h,p)
        local frame = vgui.Create("DFrame")
        frame:SetSize(w,h)
        frame:SetTitle("")
        frame:SetVisible(true) 
        frame:SetDraggable(true)
        frame:ShowCloseButton(false)
        frame:Center()
        frame:MakePopup()
        if p then frame:SetParent(p) end
        frame.Paint = function()
            draw.RoundedBox( 0, 0, 0, w, h, col2 )
            draw.RoundedBox( 0, 0, 0, w, 25, col1 )
            draw.DrawText( name, PlainLIB.Font1, 10, 5, Color(255,255,255,255), TEXT_ALIGN_LEFT )
        end
        -- Close button
        local CBtn = vgui.Create( "DImageButton", frame )        
        CBtn:Dock(NODOCK)
        local clW,clH = 30,25
        CBtn:SetSize( clW,clH )
        CBtn:SetPos( w-clW-5, 0 )
        CBtn:SetTooltip("Close window")
        CBtn.Paint = function()
            draw.RoundedBox( 4, 0, 5, clW-5, clH-10, Color( 235,0,0,130 ))
            surface.SetDrawColor( 255, 255, 255, 30 )
            surface.SetMaterial( Material( "icon16/delete.png" ) )
            surface.DrawTexturedRect( 4, 4, 16, 16 )
        end
        CBtn.DoClick = function()
            surface.PlaySound( PlainLIB.SoundClick )
            frame:Close()
        end
        CBtn.OnCursorEntered = function() surface.PlaySound( PlainLIB.SoundHover ) end
        -- Refresh button
        local RBtn = vgui.Create( "DImageButton", frame )        
        RBtn:Dock(NODOCK)
        RBtn:SetSize( clW,clH )
        RBtn:SetPos( w-clW-55, 0 )
        RBtn:SetTooltip("Refresh window")
        RBtn.Paint = function()
            draw.RoundedBox( 4, 0, 5, clW-5, clH-10, Color( 20, 230, 20, 30 ))
            surface.SetDrawColor( 255, 255, 255, 200 )
            surface.SetMaterial( Material( "icon16/arrow_refresh.png" ) )
            surface.DrawTexturedRect( 4, 4, 16, 16 )
        end
        RBtn.DoClick = function()
            surface.PlaySound( PlainLIB.SoundClick )
            frame:InvalidateLayout()
        end
        RBtn.OnCursorEntered = function() surface.PlaySound( PlainLIB.SoundHover ) end
        return frame
    end
end
