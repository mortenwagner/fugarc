-- FUGARC - "awake meets fugu"
-- (best w. crow, grids & arc)
--
-- Setup outs & aux-functions
-- & clocks in params
--
-- See more on lines forum
-- v 1.0.2 @popgoblin
-- --------------------------
-- E1 changes modes:
-- STEP/LOOP/TRACKS/OPTION
--
-- K1 held is alt *
--
-- STEP
-- E2/E3 move/change
-- K2  *clear
--
-- LOOP
-- E2 loop length
--
-- TRACKS
-- E2 selects
-- E3 changes div *transpose
-- K2/K3 step thru  modes
--
-- OPTION
-- *toggle
-- E2/E3 changes

MusicUtil = require "musicutil"


voiceClockRun 	      = {}
voiceClockDir 	      = {}
voicePatternPos       = {}

crowFxClockRun        = {}

encPos = {}

cvOuts = {'off','ACV1','ACV2','ACV3','ACV4',
          'CRW1','CRW2','CRW3','CRW4',
          'TXo1','TXo2','TXo3','TXo4'}

trOuts = {'off', 'ATR1','ATR2','ATR3','ATR4',
          'CRW1','CRW2','CRW3','CRW4',
          'TXo1','TXo2','TXo3','TXo4'}

crowOutFx = {'off',
             'Track 1 AR', 'Track 2 AR', 'Track 3 AR', 'Track 4 AR',
             'LFO * 1', 'LFO * 2', 'RND div 1', 'RND div 2',
             'Clock div 1','Clock div 2','Clock div 4','Clock div 8'}

crowFxAR = {} -- holds AR set ups
crowFxClockRun = {} -- holds clock synced events


g = grid.connect()
a = arc.connect(1)
m = midi.connect()

chainsaw = true

alt = false
altOpt = false

mode = 1

mode_names = {"STEP","LOOP","TRACKS","OPTION"}

local scale_names = {}
local notes = {}
local active_notes = {}

local edit_pos = 1

local track_no_edit = 1

--dont reset lfo if there hasnt been a div change
local last_div ={0,0,0,0}


pattern = {
  length = 16,
  data = {1,0,3,5,6,7,8,7,0,1,0,2,0,3,0,4}
}


function build_scale()
  notes = MusicUtil.generate_scale_of_length(params:get("root_note"), params:get("scale_mode"), 16)
  local num_to_add = 16 - #notes
  for i = 1, num_to_add do
    table.insert(notes, notes[16 - num_to_add])
  end
end


function add_pattern_params()
  params:add_group("PATTERN",17)

  params:add{type = "number", id = "pattern_length", name = "length", min=1, max=16,
    default = pattern.length,
    action=function(x) pattern.length = x end }

  for i=1,16 do
    params:add{type = "number", id= ("pattern_data_"..i), name = ("data "..i), min=0, max=8,
      default = pattern.data[i],
      action=function(x) pattern.data[i] = x end }
  end

end

local function patternStep(trk)
  while true do
    clock.sync(params:get("trk_"..trk.."_steps")/params:get("trk_"..trk.."_step_div"))
    --first figure out how to advance/randomize the track
    if (voiceClockDir[trk]==1) then
      voicePatternPos[trk] = voicePatternPos[trk]+1
      if voicePatternPos[trk] > pattern.length then
			  voicePatternPos[trk] = 1 end
		 elseif (voiceClockDir[trk]==2) then
      voicePatternPos[trk] =  math.floor(math.random()*pattern.length)+1
   	elseif (voiceClockDir[trk]==-1) then
      voicePatternPos[trk] = voicePatternPos[trk]-1
      if voicePatternPos[trk] < 1 then
			  voicePatternPos[trk] = pattern.length end
    elseif (voiceClockDir[trk]==-2) then
        voicePatternPos[trk] = voicePatternPos[trk]+1
        if voicePatternPos[trk] > pattern.length then voiceClockDir[trk]=-3 end
    end
	 if (voiceClockDir[trk]==-3) then
          voicePatternPos[trk] = voicePatternPos[trk]-1
      if voicePatternPos[trk] < 1 then
		  	  voiceClockDir[trk]=-2
		  	  voicePatternPos[trk]=1
		    end
    end
  --- ^ phew, that was a lot. Could probably be done a lot smarter

	--is there sound? (ie does the pattern data hold a tone ~= 0)
 		if (pattern.data[voicePatternPos[trk]] > 0) and (voiceClockDir[trk]~=0) then
			local note_num = notes[pattern.data[voicePatternPos[trk]]]
			note_num=note_num+params:get("trk_"..trk.."_transpose")
      local freq = MusicUtil.note_num_to_freq(note_num)
      -- Trig Probablility
      if math.random(100) <= params:get("probability") then
			-- play the note on the right cvOut and trOut...
          sendCV(params:get("trk_"..trk.."_cvout"), (note_num-24)/12)
          sendTrigger(params:get("trk_"..trk.."_trout"))
          --check if there is any crow output that should send trigger
          for i=1,4 do
              if crowFxAR[i]==trk then sendCrowAR(i) end
            end
          --check if there is midi-output for this track
          if m and params:get("trk_"..trk.."_midiCh")>0 then
              mvel = params:get("trk_"..trk.."_midiVel")+math.random(params:get("midiVelVar"))
              if mvel >= 127 then mvel = 127 end
              sendMidiNote(note_num,params:get("trk_"..trk.."_midiCh"),mvel)
            end
      end
		end

		if g then
      gridredraw()
    end

    if a then
       arc_redraw()
    end

    redraw()
	end
end

function sendCrowAR(out)
      crow.output[out].action = "{to(10,0.0),to(0,0.5)}"
      crow.output[out].execute()
  end

 function sendTrigger(triggerListIndex)
   if triggerListIndex==1 then return end --off
    if (triggerListIndex<6) then crow.ii.ansible.trigger_pulse(triggerListIndex-1)
      elseif (triggerListIndex>9)
          then crow.ii.txo.tr_pulse(triggerListIndex-9)
        else
        crow.output[triggerListIndex-5].action = "{pulse(0.05,10,1)}"
         crow.output[triggerListIndex-5].execute()
        end
  end

 function sendCV(cvListIndex, voltage)
    if cvListIndex==1 then return end --off
    if (cvListIndex<6) then
          crow.ii.ansible.cv(cvListIndex-1, voltage)
      elseif (cvListIndex>9)
          then crow.ii.txo.cv(cvListIndex-9,voltage)
        else
         crow.output[cvListIndex-5].volts = voltage
         crow.output[cvListIndex-5].execute()
        end
  end

 function sendMidiNote(noteNum,mChannel,mVel)
   if m then
     m:note_on(noteNum, mVel, mChannel)

      local noteOffMetro = metro.init()
        noteOffMetro.event = function() -- idea borrowed from "animator" scripts
           m:note_off(noteNum, nil, mChannel)
           metro.free(noteOffMetro.id)
         end
      local midiNoteTime = params:get("midiLen")
      if params:get("midiLenVar") > 0 then
        midiNoteTime=midiNoteTime+math.random(params:get("midiLenVar"))
        end
      noteOffMetro.time = midiNoteTime
      noteOffMetro.count = 1
      noteOffMetro:start()
    end
  end


 function clockSignal()
    while true do
      clock.sync(1/params:get("clock_div"))
      sendTrigger(params:get("clock_out"))
    end
  end

--CrowFx functions

 function crowFxClock(outNo, div)
    while true do
      clock.sync(1/div)
      sendTrigger(outNo+5) --list of outs is alphabetical; 1=off, then 4 Ansible, then the 4 crows...
    end
  end

  function crowFxRnd(outNo, div)
    while true do
      clock.sync(1/div)
      crow.output[outNo].volts = math.random(10)-5
      crow.output[outNo].execute()
    end
  end

  -- Called when editing params for crowFx.
 function setupCrowFx(crowOut, fxIndex)
    crow.output[crowOut].action="{to(0,0.0)}"

    if crowFxClockRun[crowOut] then --there is a running clock
          clock.cancel(crowFxClockRun[crowOut])
          crowFxClockRun[crowOut]=null
        end
    if crowFxAR[crowOut] then --there is an AR
        crowFxAR[crowOut]=0
      end

    --now, we ould really use a switch statement in lua!
    if (fxIndex > 1 and fxIndex<6) then --send AR with track
        crowFxAR[crowOut] = fxIndex-1
    elseif (fxIndex>9) then --crowClockOuts
        myDiv = fxIndex-9
        if myDiv==3 then myDiv=4 elseif myDiv==4 then myDiv=8 end --could most probably be done smarter :)
        crowFxClockRun[crowOut] = clock.run(crowFxClock,crowOut,myDiv)
    elseif fxIndex==6 or fxIndex==7 then --LFO - * 1 and 2
        rate=1+fxIndex-6
        crow.output[crowOut].action = "lfo("..rate..",5,sine)"
        crow.output[crowOut].execute()
    elseif fxIndex==8 or fxIndex==9 then -- Rnd - div 1 and 2
        div=1+fxIndex-8
        crowFxClockRun[crowOut]= clock.run(crowFxRnd,crowOut,div)
      end

  end

function init()
  print("Fugarc init")
 	for i = 1, #MusicUtil.SCALES do
    table.insert(scale_names, string.lower(MusicUtil.SCALES[i].name))
  end

  params:add_group("TRACKS",20)
  for i=1,4 do
   	params:add{type = "number", id = "trk_"..i.."_steps", name = "Trk "..i.." Steps", min = 1, max = 16, default = 1}
   	params:add{type = "number", id = "trk_"..i.."_step_div", name = "Trk "..i.." Div", min = 1, max = 16, default = 4}
   	params:add{type = "number", id = "trk_"..i.."_transpose", name = "Trk "..i.." Trans", min = -24, max = 24, default = 0}
   	params:add{type = "option", id = "trk_"..i.."_cvout",name = "Trk "..i.." CV out", options = cvOuts, default = i+1}
   	params:add{type = "option", id = "trk_"..i.."_trout",name = "Trk "..i.." TRIG out", options = trOuts, default = i+1}
    voiceClockDir[i] = 0
		voicePatternPos[i] = 1
		encPos[i]=0;
  end

  params:add_group("MIDI",12)
  for i=1,4 do
    -- MIDI Channel 0 == off
   	params:add{type = "number", id = "trk_"..i.."_midiCh", name = "Trk "..i.." MIDI Channel", min = 0, max = 16, default = 0}
   	params:add{type = "number", id = "trk_"..i.."_midiVel", name = "Trk "..i.." Velocity", min = 0, max = 127, default = 100}
  end
   params:add_separator()
   	params:add{type = "number", id = "midiVelVar", name = "Midi Velocity Var", min = 0, max = 127, default = 20}
   	params:add{type = "number", id = "midiLen", name = "Midi Length", min = 0.1, max = 10, default = 0.2}
  	params:add{type = "number", id = "midiLenVar", name = "Midi Length Var", min = 0, max = 1000, default = 0}


  params:add_group("CROW Fx",4)
  for i=1,4 do
    --crowOutFx
   	params:add{type = "option", id = "crow_"..i.."_fx",name = "Crow "..i.." Fx", options = crowOutFx, default = 1, action=function(x) setupCrowFx(i,x) end}
  end

	params:add{type = "option", id = "scale_mode", name = "scale mode",
    options = scale_names, default = 5,
    action = function() build_scale() end}
  params:add{type = "number", id = "root_note", name = "root note",
    min = 0, max = 127, default = 60, formatter = function(param) return MusicUtil.note_num_to_name(param:get(), true) end,
    action = function() build_scale() end}
  params:add{type = "number", id = "probability", name = "probability",
    min = 0, max = 100, default = 100,}

  crow.ii.pullup(true)
    -- check outs
    for j=1,4 do
    crow.output[j].slew = 0.0
    crow.output[j].volts=0
    crow.ii.ansible.cv(j, 0)
    crow.ii.ansible.cv_slew(j, 0)
    crow.ii.ansible.trigger_time( j, 5)
   	crow.ii.ansible.trigger_pulse(j)
   	crow.ii.txo.tr_time( j, 5)
   	crow.ii.txo.tr_pulse(j)
   	crow.ii.txo.cv(j, 0)
   	crow.ii.txo.cv_slew(j, 0)
  end

  -- extra clocks
  params:add{type = "option", id = "clock_out",name = "Clock out", options = trOuts, default = 1}
  params:add{type = "option", id = "clock_div",name = "Clock div", options = {'1','2','3','4'}, default = 1}




  params:add_separator()
  add_pattern_params()
  params:default()

  norns.enc.sens(1,8)

--everything doesnt need to start at once...
  for i=1,4 do
    voiceClockRun[i] = clock.run(patternStep,i)
  end
  --this might be redundant with the new "crowFx"-system... --TODO
  voiceClockRun[5] = clock.run(clockSignal)
end


function enc(n, delta)
  if n==1 then
    mode = util.clamp(mode+delta,1,4)
  elseif mode == 1 then --step
    if n==2 then
      if alt then
        params:delta("probability", delta)
      else
        local p = 1 and pattern.length
        edit_pos = util.clamp(edit_pos+delta,1,p)
      end
    elseif n==3 then params:delta("pattern_data_"..edit_pos, delta) end
  elseif mode == 2 then --loop
    if n==2 then
      params:delta("pattern_length", delta)
    end
  elseif mode == 3 then --tracks
    if n==2 then
      track_no_edit = util.clamp(track_no_edit+delta,1,4)
    elseif n==3 and alt==false then
      params:delta("trk_"..track_no_edit.."_step_div", delta)
      elseif n==3 and alt==true then
      params:delta("trk_"..track_no_edit.."_transpose", delta)
          end
  elseif mode == 4 then --option
    if n==2 then
      if alt==false then
        params:delta("clock_tempo", delta)
      end
    elseif n==3 then
      if alt==false then
        params:delta("root_note", delta)
      else
        params:delta("scale_mode", delta)
      end
    end
  end
  redraw()
end

function key(n,z)
  if n==2 then
    altOpt = z==1
  end
  if n==1 then
    alt = z==1
  elseif mode == 1 then --step
    if n==2 and z==1 then
      if not alt==true then
        -- toggle edit
          if edit_pos > pattern.length then edit_pos = pattern.length end
      else
        -- clear
        for i=1,pattern.length do params:set("pattern_data_"..i, 0) end
      end
    elseif n==3 and z==1 then
      if not alt==true then
        -- morph
        -- morph(pattern, "pattern")
        end
      else
        -- random
       -- random()
       -- gridredraw()
      end
  elseif mode == 2 then --loop
    if n==2 and z==1 then
      pattern.pos = 0
    elseif n==3 and z==1 then
      pattern.pos = math.floor(math.random()*pattern.length)
    end
  elseif mode == 3 then --tracks (this is where we change tracks!)
    if n==2 and z==1 then
      voiceClockDir[track_no_edit]=voiceClockDir[track_no_edit]-1
    elseif n==3 and z==1 then
      voiceClockDir[track_no_edit]=voiceClockDir[track_no_edit]+1
    end
    if (voiceClockDir[track_no_edit]>2) then voiceClockDir[track_no_edit]=2 end
    if (voiceClockDir[track_no_edit]<-2) then voiceClockDir[track_no_edit]=-2 end
  elseif mode == 4 then --option
    if n==2 then
    elseif n==3 then
    end
  end

  redraw()
end



function redraw()
  screen.clear()
  screen.line_width(1)
  screen.aa(0)
  -- edit point
  if mode==1 then
    screen.move(26 + edit_pos*6, 33)
    screen.line_rel(4,0)
    screen.level(15)
    if alt then
      screen.move(0, 30)
      screen.level(1)
      screen.text("prob")
      screen.move(0, 45)
      screen.level(15)
      screen.text(params:get("probability"))
    end
    screen.stroke()
  end
  -- steps
  for i=1,pattern.length do
    screen.move(26 + i*6, 30 - pattern.data[i]*3)
    screen.line_rel(4,0)
    --needs more work and to look at all 4 playheads
    screen.level(
        (i == voicePatternPos[1] and voiceClockDir[1]~=0) and 15
        or (i == voicePatternPos[2] and voiceClockDir[2]~=0) and 15
          or (i == voicePatternPos[3] and voiceClockDir[3]~=0) and 15
           or (i == voicePatternPos[4] and voiceClockDir[4]~=0) and 15
      or ((edit_ch == 1 and pattern.data[i] > 0) and 4 or (mode==2 and 6 or 1)))
    screen.stroke()
  end

  -- loop lengths
  screen.move(32,30)
  screen.line_rel(pattern.length*6-2,0)
  screen.move(32,60)
  screen.stroke()


  -- playposition
  for i=1,4 do
    if (voiceClockDir[i]~=0) then
      screen.move(26+6*voicePatternPos[i],4)
      screen.line_rel(0,27)
      screen.level(1)
      screen.stroke()
    end
  end
  --

  screen.level(4)
  screen.move(0,10)
  screen.text(mode_names[mode])

  if mode==4 then
    screen.level(1)
    screen.move(0,30)
    screen.text(alt==false and "bpm" or "")
    screen.level(15)
    screen.move(0,40)
    screen.text(alt==false and params:get("clock_tempo") or "")
    screen.level(1)
    screen.move(0,50)
    screen.text(alt==false and "root" or "scale")
    screen.level(15)
    screen.move(0,60)
    screen.text(alt==false and params:string("root_note") or params:string("scale_mode"))
  end

  -- display states of playheads
  screen.level(2)
  for i=1,4 do
    screen.move(8+i*24,40)
    screen.level((track_no_edit==i and mode==3) and 10 or 2)
    screen.text("Trk"..i)
    screen.move(10+i*24,48)
    screen.text(params:get("trk_"..i.."_steps").."/"..params:get("trk_"..i.."_step_div"))
    screen.move(10+i*24,56)
    screen.text("T:"..params:get("trk_"..i.."_transpose"))
    screen.move(10+i*24,64)
    screen.text(voiceClockDir[i]<-1 and "> <"
                  or voiceClockDir[i]==-1 and " < "
                  or voiceClockDir[i]==0 and ". ."
                  or voiceClockDir[i]==1 and " > "
                  or voiceClockDir[i]==2 and " R "
                  )
  end


  screen.update()
  if a then
       arc_redraw()
    end

end

set_loop_data = function(which, step, val)
  params:set(which.."_data_"..step, val)
end

function g.key(x, y, z)
  local grid_h = g.rows
  if z > 0 then
    if (grid_h == 8) or (grid_h == 16 and y <= 8) then
      if pattern.data[x] == 9-y then
        set_loop_data("pattern", x, 0)
      else
        set_loop_data("pattern", x, 9-y)
      end
    end
    gridredraw()
    redraw()
  end
end

function gridredraw()
  local grid_h = g.rows
  g:all(0)

    for x = 1, 16 do
      if pattern.data[x] > 0 then g:led(x, 9-pattern.data[x], 5) end
    end
    --paint the cursor(s)
    for i=1,4 do
      if (voiceClockDir[i]~=0) then
        for j=1,8 do
          g:led(voicePatternPos[i], j, 3)
        end
           --do we have a "hit?"
      if voicePatternPos[i] > 0 and pattern.data[voicePatternPos[i]] > 0 then
       g:led(voicePatternPos[i], 9-pattern.data[voicePatternPos[i]], 15)
      end
      end
    end



  g:refresh()
end

---arc
function a.delta(n, d)
  encPos[n]=encPos[n]+d/123
  dlt = util.round(encPos[n]+d/123, 1)
  if (dlt>=1) then encPos[n]=0 end
  if (dlt<=-1) then encPos[n]=0 end

  if alt then
      params:delta("trk_"..n.."_step_div", dlt)
  elseif altOpt then
        params:delta("trk_"..n.."_steps", dlt)
  else
    voiceClockDir[n]=voiceClockDir[n]+dlt
    if voiceClockDir[n]<-2 then voiceClockDir[n]=-2 end
    if voiceClockDir[n]>2 then voiceClockDir[n]=2 end
  end
  arc_redraw()
end

function arc_redraw()
  a:all(0)
  for i=1,4 do
    if alt then
        a:segment(i, 0,6/(16/params:get("trk_"..i.."_step_div")), 10)
      elseif altOpt then
         a:segment(i, 0,6/(16/params:get("trk_"..i.."_steps")), 10)
        else
        a:segment(i, voiceClockDir[i],voiceClockDir[i]+1, 15)
    end
  end
  a:refresh()
end

function cleanup ()
end
