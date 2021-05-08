--[[
if true then return end --]]

--[[
	Xer0X + CitRiks = x-Team
	---------------------------

	This script demonstrates unability to
	have far.Text(..) as substitute to
	non-modal always-on-top dialogs

	We need Always-on-Top dialogs!
	and editor resizing + moving as well.

https://forum.farmanager.com/viewtopic.php?f=15&t=12119
https://github.com/dr-dba/far-lua-editor-line-num-last-edit-pos/

--]]

require("Lib-Common-@Xer0X")

local FIXED_WIDTH = false -- fixed width, by the max of the all file

local F = far.Flags
local far_AdvControl = far.AdvControl
local Editor_Set = Editor.Set

local EOPT_SHOWTITLEBAR  = F.EOPT_SHOWTITLEBAR
local EOPT_SHOWKEYBAR	 = F.EOPT_SHOWKEYBAR
local EOPT_SHOWSCROLLBAR = F.EOPT_SHOWSCROLLBAR
local ACTL_GETCURSORPOS	 = F.ACTL_GETCURSORPOS
local ACTL_GETWINDOWCOUNT= F.ACTL_GETWINDOWCOUNT
local ACTL_GETWINDOWINFO = F.ACTL_GETWINDOWINFO
local ACTL_COMMIT	 = F.ACTL_COMMIT
local EE_READ		 = F.EE_READ
local EE_SAVE		 = F.EE_SAVE
local EE_CLOSE		 = F.EE_CLOSE
local EE_REDRAW		 = F.EE_REDRAW
local EE_GOTFOCUS	 = F.EE_GOTFOCUS
local EE_KILLFOCUS	 = F.EE_KILLFOCUS
local EE_CHANGE		 = F.EE_CHANGE
local EE_CUSTOM		 = 101
local ECTYPE_CHANGED	 = F.ECTYPE_CHANGED
local WTYPE_EDITOR	 = F.WTYPE_EDITOR

local tbl_event_names = {
	[  0] = "READ",
	[  1] = "SAVE",
	[  3] = "CLOSE",
	[  2] = "REDRAW",
	[  6] = "GOTFOCUS",
	[  7] = "KILLFOCUS",
	[  8] = "CHANGE",
	[101] = "CUSTOM"
}

local LINE_NUMB_COLR_RGLR	= 0x0F
local LINE_NUMB_COLR_CURR	= 0x0C
local LINE_NUMB_DRAW_TIME_CNT	= 1
local line_numb_draw_time_run	= 0
local line_numb_draw_isOn	= true

local fnc_flag_names		= Xer0X.fnc_flag_names
local fnc_cons_edit_curs_geomtr	= Xer0X.fnc_cons_edit_curs_geomtr
local t_set, is_draw_pending, edid_last
-- forward declaration:
local fnc_line_numb_draw

if not	Xer0X then _G.Xer0X	= { } end
if not	Xer0X.tbl_editors then
	Xer0X.tbl_editors	= { }
	Xer0X.tbl_edt_hist	= { }
	Xer0X.CURSOR		= { edit = { }, cons = { } }
	Xer0X.CONSOLE		= { evt_last = { } }
end
local tbl_editors	= Xer0X.tbl_editors
local tbl_edt_hist	= Xer0X.tbl_edt_hist
local curs		= Xer0X.CURSOR
local cons		= Xer0X.CONSOLE

for ii = 1, far_AdvControl(ACTL_GETWINDOWCOUNT)
do	local ii_winf = far_AdvControl(ACTL_GETWINDOWINFO, ii)
	if ii_winf.Type == WTYPE_EDITOR
	then editor.SubscribeChangeEvent(ii_winf.Id, true)
	end
end

local function fnc_find_edit_data(edid)
	local	edit_info = tbl_editors[edid]
	if	edit_info then return edit_info end
	local	cnt_edt_hist = #tbl_edt_hist
	if not	cnt_edt_hist or cnt_edt_hist == 0 then return end
	edit_info = tbl_edt_hist[cnt_edt_hist]
	if	edit_info and
		edit_info.editor_id == edid
	then	if not	edit_info.hist_rest
		then	edit_info.hist_rest = Far.UpTime
		end
		return edit_info
	end
end

local function fnc_calc_marg_coord(edid)
	local edinx	= fnc_find_edit_data(edid)
	local edinf	= edinx.edit_info
	local editor_X1 = edinx.init_size and edinx.X1 or edinx.geometry and edinx.geometry.EPosX1
	local editor_Y1 = edinx.init_size and edinx.Y1 or edinx.geometry and edinx.geometry.EPosY1
	if	editor_X1 
	and	editor_Y1
	then
		local	line_numb_marg_X = editor_X1 + edinf.WindowSizeX - edinx.line_numb_width - edinx.has_scroll
		local	line_numb_marg_Y = editor_Y1 + edinx.has_title
		return	line_numb_marg_X,
			line_numb_marg_Y
	end
end

local function fnc_prep_extd_edit(edid)
	local edinx	= fnc_find_edit_data(edid)
	if not edinx then return end
	local edinf	= edinx.edit_info
	edinx.has_scroll	= Editor_Set(15) > 0 and edinf.TotalLines > edinf.WindowSizeY and 1 or 0
	edinx.has_title		= band(edinf.Options, EOPT_SHOWTITLEBAR) == 0 and 0 or 1
	edinx.line_numb_TSLP	= edinx.line_numb_start
	edinx.line_numb_start	= edinf.TopScreenLine
	edinx.line_numb_prev	= edinx.line_numb_curr
	edinx.line_numb_curr	= edinf.CurLine
	edinx.line_numb_final	= math.min(edinf.TopScreenLine + edinf.WindowSizeY - edinx.has_title, edinf.TotalLines)
	edinx.line_numb_width	= tostring(edinf.TotalLines):len()
	edinx.line_numb_format	= FIXED_WIDTH and "%"..edinx.line_numb_width.."d" or "%s"
	edinx.line_numb_marg_X,
	edinx.line_numb_marg_Y
		= fnc_calc_marg_coord(edid)
	return edinx
end -- fnc_prep_extd_edit

function fnc_line_numb_draw_time(timer_sender, run_once, edid, t_now)
	local	edinx, edinf,
		edit_curs_pos_X,
		init_size	,
		line_numb_start	,
		line_numb_curr	,
		line_numb_prev	,
		line_numb_final	,
		line_numb_width	,
		line_numb_fmt	,
		line_numb_marg_X,
		line_numb_marg_Y,
		line_numb_colr
	if not Area.Editor then goto timer_finalize end
	line_numb_draw_time_run = line_numb_draw_time_run + 1
	if line_numb_draw_time_run > LINE_NUMB_DRAW_TIME_CNT then goto timer_finalize end
	edinx = fnc_prep_extd_edit(edid)
	if not edinx then goto timer_finalize end
	edit_curs_pos_X = curs.pstn.X
	init_size	= edinx.init_size
	line_numb_start	= edinx.line_numb_start
	line_numb_curr	= edinx.line_numb_curr
	line_numb_final	= edinx.line_numb_final
	line_numb_width	= edinx.line_numb_width
	line_numb_fmt	= edinx.line_numb_format
	line_numb_marg_X= edinx.line_numb_marg_X
	line_numb_marg_Y= edinx.line_numb_marg_Y
	if not init_size then goto timer_finalize end
	for	ii = line_numb_start, line_numb_final
	do	if 	line_numb_marg_X > edit_curs_pos_X 
		or	line_numb_curr ~= ii
		then
			line_numb_colr = ii == line_numb_curr 
				and	LINE_NUMB_COLR_CURR 
				or	LINE_NUMB_COLR_RGLR
			far.Text(
				line_numb_marg_X + (FIXED_WIDTH and 0 or line_numb_width - string.len(tostring(ii))),
				line_numb_marg_Y - line_numb_start + ii,
				line_numb_colr,
				line_numb_fmt:format(ii)
					)
		end
	end
	if run_once then goto timer_finalize end
	is_draw_pending = true
	if true then return end
	::timer_finalize::
	timer_sender:Close()
	t_set = t_now
	is_draw_pending = false
end -- fnc_line_numb_draw_time

local function fnc_edt_ext_evt_track(edid, evt, arg, prm)
	edid_last	= edid
	local t_now	= Far.UpTime
	local curs_pstn = far_AdvControl(ACTL_GETCURSORPOS)
	curs.pstn	= curs_pstn
	curs.time	= t_now
	curs.edit.X	= curs_pstn.X
	curs.edit.Y	= curs_pstn.Y
	curs.edit.T	= t_now
	curs.orig	= "editor"
	local	edinx = fnc_find_edit_data(edid)
	if not	edinx
	then    edinx = {
			editor_id = edid,
			open_orig = tbl_event_names[evt],
			t_created = t_now,
			tbl_events= {},
			cnt_events= 0
		}
		tbl_editors[edid] = edinx
	end
        local	tbl_evt = edinx.tbl_events[evt]
	if not	tbl_evt
	then	tbl_evt = {
			A1 = arg,
			P1 = prm,
			T1 = t_now,
			C1 = curs.pstn,
			N = tbl_event_names[evt],
			cnt = 0
		}
		edinx.tbl_events[evt] = tbl_evt
	end
	if	tbl_evt.cnt == 1
	then	tbl_evt.A2 = arg
		tbl_evt.T2 = t_now
		tbl_evt.C2 = curs.pstn
	end
	tbl_evt.cnt = tbl_evt.cnt + 1
	tbl_evt.AL = arg
	tbl_evt.PL = prm
	tbl_evt.TL = t_now
	tbl_evt.CL = curs.pstn
	if
	not	edinx.evt_Fst
	then	edinx.evt_Fst = tbl_evt
	elseif
	not	edinx.evt_Scd
	then	edinx.evt_Scd = tbl_evt
	elseif
	not	edinx.evt_Thd
	then	edinx.evt_Thd = tbl_evt
	end
	edinx.cnt_events = edinx.cnt_events + 1
	local edit_info = editor.GetInfo(edid)
	edinx.edit_info_prev = edinx.edit_info
	edinx.curs_pstn_prev = edinx.evt_Lst and edinx.evt_Lst.CL
	edinx.evt_Lst = tbl_evt
	if not  edinx.edtSt_int and Area.Editor
	then
		local	edinf = editor.GetInfo()
        	if	edinf 
        	and	edinf.EditorID == edid
		then
                        edinx.edtSt_int = Editor.State
			edinx.edtSt_str,
			edinx.edtSt_tbl =
				fnc_flag_names(Editor.State, "^EF_")
			edinx.edtSt_upd = t_now
			edinx.edtSt_crs = curs.pstn
			edinx.edtSt_udr = Far.UpTime
		end
	end
	if not	edinx.wind_info
	then
		local ii_winf, wnd_cnt
		wnd_cnt = far.AdvControl(ACTL_GETWINDOWCOUNT)
		for	ii = 1, wnd_cnt 
		do	ii_winf = far.AdvControl(ACTL_GETWINDOWINFO, ii)
			if not	ii_winf then break end
			if	ii_winf.TypeName == "Edit" 
			and	ii_winf.Id == edid
			then	edinx.wind_info = ii_winf
				edinx.wind_info_time = t_now
                                edinx.wind_info_curs = curs.pstn
				edinx.flags_wnd	= fnc_flag_names(ii_winf.Flags, "^WIF_")
				edinx.wind_info_time_real = Far.UpTime
			end
		end
	end
	if	evt == EE_CLOSE
	then	if not	edinx.hist_rest
		then	tbl_edt_hist[#tbl_edt_hist + 1] = edinx
			tbl_editors[edid] = nil
		end
	elseif	evt == EE_READ
	then	editor.SubscribeChangeEvent(edid, true)
	elseif	evt == EE_CHANGE 
	and	arg.Type == ECTYPE_CHANGED
	then	if (edit_info or edinx.edit_info).CurLine == arg.StringNumber
	 	then edinx.last_edit_pstn = (edit_info or edinx.edit_info)
		end
	end
	if not	edinx.init_size and
	not	edinx.tbl_events[EE_CLOSE]
	then	if not	edinx.init_curs 
		and (	edinx.evt_Fst.C1.X ~= curs_pstn.X 
		or	edinx.evt_Fst.C1.Y ~= curs_pstn.Y )
		then	edinx.init_curs = t_now
		end
                if	edinx.init_curs 
                and	edinx.init_curs < t_now 
                and	edinx.tbl_events[EE_GOTFOCUS] 
                and	edinx.tbl_events[EE_READ] 
                and	edinx.tbl_events[EE_REDRAW]
                then	edinx.geometry = fnc_cons_edit_curs_geomtr(edid, edinx.edit_info, edinx.curs_pstn)
			local	POS_SET_MAX = 3
                	if	edinx.cnt_events < 10 
			or not	edinx.pos_set 
			or	edinx.pos_set_cnt < POS_SET_MAX
                	then
				far.Timer(20, function(sender, edid)
					if	sender.Closed 
					or not	sender.Enabled 
					then	return
					end
					if not	Area.Editor
					then	sender.Enabled = false
						sender:Close()
						return
					end
					local	edinx = fnc_find_edit_data(edid)
					if	edinx.hist_rest
					then	sender.Enabled = false
						sender:Close()
						return
					end
					local	edinf = edinx.edit_info
					if not	edinf
					then	sender.Enabled = false
						sender:Close()
						return
					end
					editor.SetPosition(edid, { CurLine = edinf.CurLine, CurPos = edinf.CurPos })
					edinx.pos_set		= true
					edinx.pos_set_tAF	= edinx.pos_set_tAF or t_now
					edinx.pos_set_tRF	= edinx.pos_set_tRF or Far.UpTime
					edinx.pos_set_cnt	= (edinx.pos_set_cnt or 0) + 1
					if	edinx.pos_set_cnt > POS_SET_MAX
					then	sender.Enabled = false
						sender:Close()
						return
					end
				end, edid)
			end
			if	edinx.pos_set and
				edinx.pos_set_tRF < t_now
			then
				far.Timer(20, function(sender, edid)
					if	sender.Closed 
					or not	sender.Enabled
					then	return
					end
					sender.Enabled = false
					sender:Close()
					local edinx = fnc_find_edit_data(edid)
					if edinx.hist_rest then return end
					edinx.X1 = edinx.geometry.EPosX1
					edinx.Y1 = edinx.geometry.EPosY1
					edinx.X2 = edinx.geometry.EPosX2
					edinx.Y2 = edinx.geometry.EPosY2
					edinx.init_size = t_now
					edinx.init_size_real = Far.UpTime
					mf.postmacro(editor.Redraw, edid)
				end, edid)
                	end
		end
	end
	edinx.edit_info		= edit_info or edinx.edit_info
	edinx.edit_info_time	= t_now
	edinx.edit_info_curs	= curs.pstn
	edinx.edit_info_time_real = Far.UpTime
	return edinx
end

fnc_line_numb_draw = function(edid, evt, arg, prm)
	local	t_now = Far.UpTime
	if not	Area.Editor 
	or not	line_numb_draw_isOn
	then	is_draw_pending = false
		return
	end
	if	is_draw_pending 
	then	return
	end
	local	sender
	if type(edid) == "userdata" 
	then	sender, edid,	evt, arg, prm =
                edid,	evt,	arg, prm, nil
	end
	edid = edid or edid_last
	local	edinx = fnc_find_edit_data(edid)
	if not	edinx 
	or	edinx.hist_rest 
	then	is_draw_pending = false
		return
	end
	if 	Xer0X.line_numb_frwd_isOn == false
	then	-- because it is event (message) based
		Xer0X.line_numb_frwd_isOn = nil
		edinx.line_numb = false
		is_draw_pending = false
		line_numb_draw_isOn = false
		return
	end
	if not	edinx.tbl_events[EE_READ] 
	or not	edinx.tbl_events[EE_REDRAW] 
	or not	edinx.tbl_events[EE_GOTFOCUS]
	then	return
	end
	if not	edinx.init_size
	then	far.Timer(20,
			function(sender, edid)
				sender.Enabled = false; sender:Close()
				if Area.Editor then editor.Redraw(edid) end
			end,
			edid)
		is_draw_pending = false
		return
	end
	is_draw_pending = true
	line_numb_draw_time_run = (evt == EE_READ) and -3 or 0
	far.Timer(200, fnc_line_numb_draw_time, false, edid, t_now)
end -- fnc_line_numb_draw

local tmr_fresh_line = far.Timer(1000, fnc_line_numb_draw)

Event {	description = "EditorEvent for updating line numeration in current editor";
	group = "EditorEvent";
	action = function(edid, evt, arg, prm)
		local edit_info = fnc_edt_ext_evt_track(edid, evt, arg, prm)
		if line_numb_draw_isOn and (
			evt == EE_GOTFOCUS	or
			evt == EE_READ		or
			evt == EE_REDRAW
				)
		then fnc_line_numb_draw(edid, evt, arg, prm)
		end
	end;
}

Event { description = "track cursor position";
	group = "ConsoleInput";
	action = function(evt, arg)
-- ###
local curs_pstn = far_AdvControl(ACTL_GETCURSORPOS)
curs.time = Far.UpTime
curs.pstn = curs_pstn
curs.orig = "console"
curs.cons.X = curs_pstn.X
curs.cons.Y = curs_pstn.Y
curs.cons.T = curs.time
cons.evt_last.evt = evt
cons.evt_last.arg = arg
cons.evt_last.time = curs.time
-- @@@
	end;
}

Macro { description = "Switch line numbering on or off";
	area = "Editor";
	key = "AltL";
	action = function(sender)
		line_numb_draw_isOn = not (line_numb_draw_isOn and tbl_editors[edid_last].line_numb);
		tbl_editors[edid_last].line_numb = line_numb_draw_isOn
	end;
}

Macro { description = "Go to last edit position";
	area = "Editor";
	key = "Ctrl-";
	action = function(sender)
		if tbl_editors[edid_last].last_edit_pstn 
		then editor.SetPosition(edid_last, tbl_editors[edid_last].last_edit_pstn)
		end
	end;
}

-- @@@@@
