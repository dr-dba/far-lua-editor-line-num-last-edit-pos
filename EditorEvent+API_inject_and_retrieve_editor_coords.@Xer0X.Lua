--[[
if true then return end --]]

--[[
https://forum.farmanager.com/viewtopic.php?f=15&t=12119
https://github.com/dr-dba/far-lua-editor-line-num-last-edit-pos/

DEPENDS ON:
https://github.com/dr-dba/far-lua-general-utils
]]

require("Lib-Common-@Xer0X")

local EE_CLOSE			= far.Flags.EE_CLOSE
local ACTL_GETWINDOWCOUNT	= far.Flags.ACTL_GETWINDOWCOUNT
local ACTL_GETWINDOWINFO	= far.Flags.ACTL_GETWINDOWINFO

if not	Xer0X.tbl_editors 
then
	Xer0X.tbl_editors	= { }
	Xer0X.tbl_edt_hist	= { }
	Xer0X.CURSOR		= { edit = { }, cons = { } }
	Xer0X.CONSOLE		= { evt_last = { } }
end
local tbl_editors	= Xer0X.tbl_editors
local tbl_edt_hist	= Xer0X.tbl_edt_hist
local curs		= Xer0X.CURSOR
local cons		= Xer0X.CONSOLE
if not	editor.Editor__orig 
and	debug.getinfo(editor.Editor, "S").what == "C"
then	editor.Editor__orig = editor.Editor
end

_G.editor.Editor = function(FileName, Title, X1, Y1, X2, Y2, Flags, StartLine, StartChar, CodePage, allow_line_numb)
	Xer0X.line_numb_frwd_isOn = allow_line_numb == nil and true or allow_line_numb or false
	local	tbl_prexist_edits = { }
	local	wnd_cnt = far.AdvControl(ACTL_GETWINDOWCOUNT)
	local	ii_wndinf
	for	ii = 1, wnd_cnt 
	do	ii_wndinf = far.AdvControl(ACTL_GETWINDOWINFO, ii)
		if ii_wndinf.TypeName == "Edit" 
		then	tbl_prexist_edits[ii_wndinf.Id] = ii_wndinf
			tbl_prexist_edits[ii_wndinf.Id].order_number = ii
		end
	end
	local	open_rslt = editor.Editor__orig(FileName, Title, X1, Y1, X2, Y2, Flags, StartLine, StartChar, CodePage)
	local	Flags_tbl, Flags_str
	if	Flags 
	and	type(Flags) ~= "table"
	then	Flags_str, Flags_tbl = Xer0X.fnc_flag_names(Flags, "^EF_")
	else	Flags_tbl = Flags
	end
	wnd_cnt = far.AdvControl(ACTL_GETWINDOWCOUNT)
	for	ii = 1, wnd_cnt 
	do	ii_wndinf = far.AdvControl(ACTL_GETWINDOWINFO, ii)
		if not	ii_wndinf then break end
		if	ii_wndinf.TypeName == "Edit" and
		not 	tbl_prexist_edits[ii_wndinf.Id]
		then
			local	edtSt_str = "Unknown"
			local	edtSt_int = -1
			local	edtSt_tbl = { }
			local	edtOp_str = "Unknown"
			local	edtOp_int = -1
			local	edtOp_tbl = { }
			local	editor_id = ii_wndinf.Id
			local	edit_info = editor.GetInfo(editor_id)
			local	edinfCurr = editor.GetInfo()
			if	edit_info.EditorID
			then	edtOp_int = edit_info.Options
				edtOp_str,
				edtOp_tbl =
					Xer0X.fnc_flag_names(edtOp_int, "^EOPT_")
			else	edit_info = nil
			end
			if	Area.Editor	and
				edit_info	and
				edit_info.EditorID ==
				edinfCurr.EditorID
			then	edtSt_int = Editor.State
				edtSt_str,
				edtSt_tbl =
					Xer0X.fnc_flag_names(edtSt_int, "^EF_")
			end
			local	isLate
			local	t_created = Far.UpTime
			local	edinx = tbl_editors[ii_wndinf.Id]
			if	edinx
			then 	isLate = true
			else	edinx = {
					editor_id = ii_wndinf.Id,
					t_created = Far.UpTime,
					late_bind = true,
					open_orig = "OPEN",
					tbl_events= { },
					cnt_events= 0
				};
			end
			edinx.wind_info = ii_wndinf
			edinx.flags_wnd	= Xer0X.fnc_flag_names(ii_wndinf.Flags, "^WIF_")
			edinx.open_file	= FileName	or isLate and edinx.open_file
			edinx.openTitle	= Title		or isLate and edinx.openTitle
			edinx.X1	= X1
			edinx.Y1	= Y1
			edinx.X2	= X2
			edinx.Y2	= Y2
			edinx.openFlags = Flags_tbl
			edinx.edtSt_int = edtSt_int	or isLate and edinx.edtSt_int
			edinx.edtSt_str = edtSt_str	or isLate and edinx.edtSt_str
			edinx.edtSt_tbl = edtSt_tbl	or isLate and edinx.edtSt_tbl
			edinx.edtOp_int = edtOp_int	or isLate and edinx.edtOp_int
			edinx.edtOp_str = edtOp_str	or isLate and edinx.edtOp_str
			edinx.edtOp_tbl = edtOp_tbl	or isLate and edinx.edtOp_tbl
			edinx.startLine = StartLine	or isLate and edinx.startLine
			edinx.startChar = StartChar	or isLate and edinx.startChar
			edinx.code_page = CodePage	or isLate and edinx.code_page
			edinx.edit_info = edit_info	or isLate and edinx.edit_info
			edinx.line_numb = allow_line_numb
			edinx.open_rslt = open_rslt
			tbl_editors[ii_wndinf.Id] = edinx
			Xer0X.line_numb_frwd_isOn = nil
			break;
		end
	end
	return open_rslt
end

_G.editor.State_EOPT = function(edid)
	local edinf = editor.GetInfo(edid)
	return Xer0X.fnc_flag_names(edinf.Options,"^EOPT_")
end -- State_EOPT

_G.editor.State_EF = function()
	return Xer0X.fnc_flag_names(Editor.State, "^EF_")
end -- State_EF


-- @@@@@
