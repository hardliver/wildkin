-- factory_test.lua：鐵輪工廠（W73）的測試：升降梯、門都通到走得過去的格子；三條生產線；社長的隊伍

do
  -- 每張地圖的升降梯（lift）、門（door）、木筏（raft）：目的地存在，到達的那一格不是牆
  local n = 0
  for name, objs in pairs(MAPOBJ) do
    for _, o in ipairs(objs) do
      if o.type == "lift" or o.type == "door" or o.type == "raft" then
        local m = MAP[o.to]
        assert(m, name .. " 的 " .. o.type .. " 通往不存在的地圖 " .. tostring(o.to))
        assert(mget(m, "solid", o.tx, o.ty) == 0, name .. " 的 " .. o.type .. " 到 " .. o.to .. " (" .. o.tx .. "," .. o.ty .. ") 是牆")
        n = n + 1
      end
    end
  end
  assert(n > 0, "應該找得到門")

  -- 工廠：三個控制台各對一條線，顧著的工人是存在的訓練家
  local lines = {}
  for _, o in ipairs(MAPOBJ.factory) do
    if o.type == "console" then lines[o.line] = true end
    if o.type == "npc" and o.trainer then assert(DATA.trainers[o.trainer], "工廠的訓練家 " .. o.trainer .. " 不在 trainers.json") end
  end
  assert(lines.wood and lines.ore and lines.light, "三條生產線都要有控制台")

  -- 三條線都停了才算（高處長才讓路）
  local saved = FLAGS
  FLAGS = { line_wood = true, line_ore = true }
  assert(not factory_lines_done(), "還有一條線在跑")
  FLAGS.line_light = true
  assert(factory_lines_done(), "三條線都停了")
  FLAGS = saved

  -- 社長室的電梯要發電；社長的隊伍 4 隻
  local need = nil
  for _, o in ipairs(MAPOBJ.factory) do if o.type == "lift" and o.to == "office" then need = o.need end end
  assert(need == "power", "往社長室的電梯要會發電的野伴")
  assert(#DATA.trainers.boss.party == 4, "社長有 4 隻野伴")
  print("ok: 鐵輪工廠")
end
