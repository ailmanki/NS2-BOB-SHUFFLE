local inspect = require('lib.inspect')
if not os.execute("clear") then
    os.execute("cls")
end
----asd----------------------------------------------
asd

-- Splits player data into teams
local function getTeam(i_players, teamName, maxPlayers)
    maxPlayers = maxPlayers or math.huge
    local team = {}
    for i = 1, #i_players do
        if (i_players[i].pref == teamName and maxPlayers > #team) then
            table.insert(team, i_players[i])
        end
    end
    return team
end

-- computes the mean value of team members skills
local function mean(i_players, t_team)
    local sum = 0
    local count = #i_players
    for i = 1, count do
        sum = sum + i_players[i][t_team]
    end

    if count then
        return sum / count
    else
        return 0
    end
end

-- computes the variance of team members skills, using a previously computed mean(average) m
-- Use the classic variance definition from https://en.wikipedia.org/wiki/Variance
-- function taken from https://github.com/Bytebit-Org/lua-statistics/blob/master/src/statistics.lua#L119
local function variance(i_players, t_team, m_teamMean)
    local varianceSum = 0
    local count = #i_players
    for i = 1, count do
        local difference = i_players[i][t_team] - m_teamMean
        varianceSum = varianceSum + (difference * difference)
    end
    -- this test is costly here (because nested in loops ultimately)
    -- could be removed by avoiding shuffling when too few players are present
    if 0 < count - 1 then
        return varianceSum / (count - 1) -- usual definition of variance (usual bias)
    else
        return 0
    end
end

-- computes the skewness of team members skills, using a previously computed mean and variance.
-- Use Fisher’s moment coefficient of skewness at https://en.wikipedia.org/wiki/ Skewness.
-- Avoid useless computations (mostly redundant divisions) by using the expanded formula
local function skewness(i_players, t_team, m_teamAverage, v_teamVariance)
    local cube = 0
    local count = #i_players
    for i = 1, count do
        cube = cube + (i_players[i][t_team] * i_players[i][t_team] * i_players[i][t_team])
    end
    -- if non-positive, then we don't have enough data / players
    -- this test is costly here (because nested in loops ultimately)
    -- could be removed by avoiding shuffling when too few players are present
    if 0 < count and 0 < v_teamVariance then
        cube = cube / count
        return (cube - 3 * m_teamAverage * v_teamVariance - m_teamAverage * m_teamAverage * m_teamAverage) / (math.sqrt(v_teamVariance) * v_teamVariance)
    else
        return 0
    end
end

-- computes a kind of relative gap between two values.
-- This function must return 0 if values are equal, it must get near 1 when values are different.
-- It must accounts for o negative values because skewness values can be negative and of opposite signs.
-- A proposed formula for such a function is:
-- relative(x,y) = |x−y| / |x|+|y|+|x+y|
-- I made it up to be able to 0compare moves later, check this choice on wolfram alpha for instance to get an
-- idea of how it works. In the case of the denominator being too small (< 10 −12 for instance); just
-- return 0 because it means that both values are really low and negligible for our purposes.
local function relative(x, y)
    local abs = math.abs
    local denominator = abs(x) + abs(y) + abs(x + y)
    -- really 1e-12 should be small enough given test data skewness, we simply want to avoid dividing by zero
    -- we also want "continuity" in zero of this function for x=y
    -- this (costly because ultimately nested in loops) test could be removed by ensuring we never shuffle with too few players
    -- then we would always have non-zero variance/skewness and computations could be performed without risk
    if 1e-12 < denominator then
        return abs(x - y) / denominator
    else
        return 0
    end
end

-- computes a coefficient that gets higher the more the teams are unbalanced.
-- The more the skill distributions are similar in terms of mean, variance, skewness (not necessarily normal
-- distribution, simply alike), the lower the coefficient gets.
--
-- This function will be used to choose what player swaps/switches to make later on.
-- Its results is between 0 (perfect equality) and 3 (worst case).
-- In theory, returning only relative(s1,s2) should work to choose moves that can
-- balance teams because it contains the mean and variance. But for safety, we
-- put an emphasis on balance average skill and variance on their own.
local function asymmetry(t1, t2)
    local m1 = mean(t1, "marine")
    local m2 = mean(t2, "alien")
    local v1 = variance(t1, "marine", m1)
    local v2 = variance(t2, "alien", m2)
    local s1 = skewness(t1, "marine", m1, v1)
    local s2 = skewness(t2, "alien", m2, v2)
    return relative(m1, m2) + relative(v1, v2) + relative(s1, s2)
end


-- little helper to swap players
local function swapPlayers(t1, t2, i, j)
    local tmp = t1[i] -- only one temporary variable should work from my understanding of lua references/copy
    t1[i] = t2[j]
    t2[j] = tmp
    return t1, t2
end

-- It must basically keep swapping players between teams until no better swap is found.
-- So it has three nested loops, an external while loop, and two internal for
-- loops over t 1 and t 2 respectively. Inside the nested for loops, try swapping two
-- players and evaluate asymmetry(t 1 ,t 2 ) with the new teams. Once all possible
-- swaps have been evaluated, apply the best one, the one minimizing asymmetry.
-- Break off the while loop once no better swap can be found.
local function swap(t1, t2)
    local old_asym = 3 -- impossible worst initial value to enter loop once at least
    local new_asym = asymmetry(t1, t2) -- current value, before any swap
    local count1 = #t1 -- players in team1
    local count2 = #t2 -- players in team2 (actually same as team 1 but could be different if we implement no switch() function)
    local i_index = -1 -- impossible initial index
    local j_index = -1 -- impossible initial index

    -- really forget about iter for now
    -- later count iterations with a global variable if performance is bad to see what is a problem
    while (new_asym < old_asym) do
        -- while we find a move to improve balance
        old_asym = new_asym
        for i = 1, count1 do
            -- loop over team 1 players
            for j = 1, count2 do
                -- loop over team 2 players
                -- swap players i and j of teams 1 and teams 2 respectively
                -- something like t1[i], t2[j] = t2[j], t1[i]
                t1, t2 = swapPlayers(t1, t2, i, j)
                -- recompute asymmetry of the teams with the swapped players to see if it’s lower
                local cur_asym = asymmetry(t1, t2)
                if cur_asym < new_asym then
                    -- if we found a lower asym we save the swap to make to get it
                    new_asym = cur_asym -- we save the better asym to get only the best move
                    i_index = i
                    j_index = j
                end
                -- restore the teams to their original state to try other moves
                -- something like t1[i], t2[j] = t2[j], t1[i]
                t1, t2 = swapPlayers(t1, t2, i, j)
            end
        end
        -- i think you moved indexes declaration out of the loop so it must now become:
        -- (otherwise indexes will always be initialized to some value once a move was found in a previous iteration)
        if new_asym < old_asym then
            -- we know there is a better move not thanks to indexes but lower asym
            -- swap (i_index player on team 1 with j_index player on team 2) something like t1[i_index], t2[j_index] = t2[j_index], t1[i_index]
            t1, t2 = swapPlayers(t1, t2, i_index, j_index)
        else
            break -- to avoid double testing the same (new_asym < old_asym) in "while (...) do"
        end
    end
    return t1, t2 -- the updated teams
end
local function swapPairs(t1, t2)
    local old_asym = 3 -- impossible worst initial value to enter loop once at least
    local new_asym = asymmetry(t1, t2) -- current value, before any swap
    local count1 = #t1 -- players in team1
    local count2 = #t2 -- players in team2 (actually same as team 1 but could be different if we implement no switch() function)
    local i_index = -1 -- impossible initial index
    local j_index = -1 -- impossible initial index
    local k_index = -1 -- impossible initial index
    local l_index = -1 -- impossible initial index

    -- really forget about iter for now
    -- later count iterations with a global variable if performance is bad to see what is a problem
    while (new_asym < old_asym) do
        -- while we find a move to improve balance
        old_asym = new_asym
        for i = 1, count1 do
            -- loop over team 1 players
            for j = 1, count2 do
                -- loop over team 2 players
                -- swap players i and j of teams 1 and teams 2 respectively
                -- something like t1[i], t2[j] = t2[j], t1[i]
                t1, t2 = swapPlayers(t1, t2, i, j)
                for k = 1, count1 do
                    -- loop over team 1 players
                    for l = 1, count2 do
                        if (k ~= i and l ~= j) then
                          -- loop over team 2 players
                          -- swap players i and j of teams 1 and teams 2 respectively
                          -- something like t1[i], t2[j] = t2[j], t1[i]
                          t1, t2 = swapPlayers(t1, t2, k, l)
                          -- recompute asymmetry of the teams with the swapped players to see if it’s lower
                          local cur_asym = asymmetry(t1, t2)
                          if cur_asym < new_asym then
                              -- if we found a lower asym we save the swap to make to get it
                              new_asym = cur_asym -- we save the better asym to get only the best move
                              i_index = i
                              j_index = j
                              k_index = k
                              l_index = l
                          end
                          -- restore the teams to their original state to try other moves
                          -- something like t1[i], t2[j] = t2[j], t1[i]
                          t1, t2 = swapPlayers(t1, t2, k, l)
                        end
                    end
                end
                -- restore the teams to their original state to try other moves
                -- something like t1[i], t2[j] = t2[j], t1[i]
                t1, t2 = swapPlayers(t1, t2, i, j)
            end
        end
        -- i think you moved indexes declaration out of the loop so it must now become:
        -- (otherwise indexes will always be initialized to some value once a move was found in a previous iteration)
        if new_asym < old_asym then
            -- we know there is a better move not thanks to indexes but lower asym
            -- swap (i_index player on team 1 with j_index player on team 2) something like t1[i_index], t2[j_index] = t2[j_index], t1[i_index]
            t1, t2 = swapPlayers(t1, t2, i_index, j_index)
            t1, t2 = swapPlayers(t1, t2, k_index, l_index)
        else
            break -- to avoid double testing the same (new_asym < old_asym) in "while (...) do"
        end
    end
    return t1, t2 -- the updated teams
end
local function pick_loop(t0, t1, t2, n)
    -- we need n to get the right team skill but makes code look horrible
    local old_asym = 3 -- impossibly bad value because we just look for the best pick but we have to pick anyways...
    -- ... so since we have to pick, we allow a higher asym even if we try to minimize asym with a pick
    local index = -1 -- impossible value to initialize
    local count0 = #t0
    for k = 1, count0 do
        -- try to add any player from RR to smallest team
        -- append t0[k] to smallest team
        if n == 1 then
            -- we add to team1
            -- add the k-th player to team 1
            table.insert(t1, t0[k])
        else
            -- we add to team2
            -- add the k-th player to team 2
            table.insert(t2, t0[k])
        end
        local cur_asym = asymmetry(t1, t2) -- recompute asymmetry with the new teams
        if cur_asym < old_asym then
            -- if we found a better pick to balance out
            index = k -- we save the index of the player to add
            old_asym = cur_asym -- to minimize asymmetry
        end
        -- restoring teams before looping over to try another pick:
        if n == 1 then
            -- we need to pop out team 1 the added player
            -- pop out code
            table.remove(t1)
        else
            -- we need to pop out team 2 the added player
            -- pop out code
            table.remove(t2)
        end
    end
    -- append saved best pick to smallest team:
    -- a pick should always be found because initial asym is 3 and teams were checked in parent function
    if n == 1 then
        table.insert(t1, t0[index])
    else
        table.insert(t2, t0[index])
    end

    -- remove t0[index] player from t0 table
    table.remove(t0, index)
    -- return teams in the right order
    return t0, t1, t2
end

-- takes non-afk ready room players and fills up the teams if these are not full already. Loop over available
-- ready room players and evaluate asymmetry(t 1 ,t 2 ) with the added player to
-- the team with fewer players. Once all possible picks have been evaluated, apply
-- the best one, the one that minimizes asymmetry. Keep doing that until teams
-- are full or no players are available.
--
-- picking players from ready room to minimize asymmetry
-- at some point check that #ti =< #tmax
local function pick(t0, t1, t2, maxPlayersTeam)
    -- as long as we have available players and teams that are not full
    while 0 < #t0 and (#t1 < maxPlayersTeam or #t2 < maxPlayersTeam) do
        -- which team has less players?
        if #t1 < #t2 then
            -- adding to team 1
            t0, t1, t2 = pick_loop(t0, t1, t2, 1)
        else
            -- adding to team2 also default
            -- could be improved by adding to the team that balances it out better
            -- would need an entirely new function as a default case
            t0, t1, t2 = pick_loop(t0, t1, t2, 2)
        end
    end
    return t1, t2
end

-- a common function that switches player from larger team to smaller one
-- takes old_asym as a constraint to choose a pick
-- returns the new_asym as well
local function switch_loop(t1, t2, n, old_asym)
    local new_asym = old_asym -- init with current asymmetry state (may be redundant)
    local index = -1 -- impossible negative value to test later
    if n == 1 then
        -- we are adding to team 1 from team 2
        local count2 = #t2
        for j = 1, count2 do
            --looping over team 2

            table.insert(t1, t2[j]) -- adding t2[j] to t1
            table.remove(t2, j)
            local cur_asym = asymmetry(t1, t2) -- compute new asymmetry
            if cur_asym < new_asym then
                -- is it better?
                new_asym = cur_asym -- save the new lowest asym
                index = j -- save the best player to switch index
            end
            -- restore teams as they were to try new switches
            table.insert(t2, j, t1[#t1])
            table.remove(t1)

        end
        if 0 < index then
            -- we found a switch to make so apply it
            table.insert(t1, t2[index]) -- add player to team 1 from team 2
            table.remove(t2, index) -- remove t2[index] player from team 2
        end
    else
        -- we are adding to team 2 from team 1
        local count1 = #t1
        for i = 1, count1 do
            --looping over team 1
            table.insert(t2, t1[i]) -- adding t2[j] to t1
            table.remove(t1, i)

            local cur_asym = asymmetry(t1, t2) -- compute new asymmetry
            if cur_asym < new_asym then
                -- is it better?
                new_asym = cur_asym -- save the new lowest asym
                index = i -- save the best player to switch index
            end
            -- restore teams as they were to try new switches
            table.insert(t1, i, t2[#t2])
            table.remove(t2)
        end
        if 0 < index then
            -- we found a switch to make so apply it
            table.insert(t2, t1[index]) -- add player to team 2 from team 1
            table.remove(t1, index) -- remove t1[index] player from team1
        end
    end
    return t1, t2, new_asym
end

-- a function to switch players while caring for a lower asymmetry
local function switch(t1, t2)
    local old_asym = 3
    local new_asym = asymmetry(t1, t2)
    while (new_asym < old_asym) do
        -- while we find an optimization to make
        old_asym = new_asym -- update to break off if needed
        if #t1 < #t2 then
            -- which team has less players
            t1, t2, new_asym = switch_loop(t1, t2, 1, old_asym) -- adding to team 1 from team 2, if we can also lower asymmetry
        else
            t1, t2, new_asym = switch_loop(t1, t2, 2, old_asym) -- adding to team 2 from team 1, if we can also lower asymmetry
        end
    end
    return t1, t2
end

-- here we balance the number of players even if we get a worse (an higher) asymmetry because it's more important
-- but we still try to minimize the asymmetry we get in switch_loop()
local function move(t1, t2)
    while 1 < math.abs(#t1 - #t2) do
        -- while teams are too unbalanced in terms of #players
        -- the 3 variable is ignored, because switch_loop returns a useless new asymmetry in this case
        if #t1 < #t2 then
            -- if team2 has more players than team1
            t1, t2, _ = switch_loop(t1, t2, 1, 3) -- add to team 1 from team 2 with initial asym very high because we don't care yet
        else
            t1, t2, _ = switch_loop(t1, t2, 2, 3) -- add to team 2 from team 1 with initial asym very high because we don't care yet
        end
    end
    return t1, t2
end

-- helper function to show informations about the teams created
local function showTeams(t0, t1, t2)
    -- strpad left function
    local function lpad (s, l)
        s = s .. ""
        local res = string.rep(' ', l - #s) .. s
        return res, res ~= s
    end

    local m_marineMean = mean(t1, "marine")
    local m_alienMean = mean(t2, "alien")
    local v_marineVariance = variance(t1, "marine", m_marineMean)
    local v_alienVariance = variance(t2, "alien", m_alienMean)
    local v_marineSkewness = skewness(t1, "marine", m_marineMean, v_marineVariance)
    local v_alienSkewness = skewness(t2, "alien", m_alienMean, v_alienVariance)
    local asymmetryTeams = asymmetry(t1, t2)

    print("Marine Mean: " .. string.format("%.5f", m_marineMean))
    print("Alien Mean: " .. string.format("%.5f", m_alienMean))
    print("Marine Variance: " .. string.format("%.5f", v_marineVariance))
    print("Alien Variance: " .. string.format("%.5f", v_alienVariance))

    print("Marine Skewness: " .. string.format("%.5f", v_marineSkewness))
    print("Alien Skewness: " .. string.format("%.5f", v_alienSkewness))

    print("Asymmetry Teams: " .. string.format("%.5f", asymmetryTeams))

    table.sort(t1, function(k1, k2)
        return k1.marine < k2.marine
    end)
    table.sort(t2, function(k1, k2)
        return k1.alien < k2.alien
    end)

    local max = math.max(#t0, #t1, #t2)
    for i = 1, max do
        local marineString = lpad('', 20)
        if t1[i] ~= nil then
            marineString = lpad(t1[i].id, 3) .. lpad(t1[i].name, 12) .. lpad(t1[i].marine, 5)
        end
        local alienString = ''
        if t2[i] ~= nil then
            alienString = " " .. lpad(t2[i].id, 3) .. lpad(t2[i].name, 12) .. lpad(t2[i].alien, 5)
        end
        local noneString = ''
        if t0[i] ~= nil then
            noneString = " " .. lpad(t0[i].id, 3) .. lpad(t0[i].name, 12) .. lpad(t0[i].marine, 5) .. lpad(t0[i].alien, 5)
        end
        print(lpad(i, 2) .. marineString .. alienString .. noneString)
    end
    print(lpad('Marines ' .. #t1, 22) .. lpad('Aliens ' .. #t2, 21) .. lpad('None ' .. #t0, 21))
end

local function main(t0, t1, t2, maxPlayersTeam)
    t1, t2 = pick(t0, t1, t2, maxPlayersTeam)

    if #t1 == #t2 then
        t1, t2 = swap(t1, t2) -- we swap to balance, #t1 == #t2 remains true
        t1, t2 = swapPairs(t1, t2)
    else
        t1, t2 = move(t1, t2) -- balances number of players between teams until |#t1 - #t2| == 1 is true
        t1, t2 = switch(t1, t2) -- may change #t1 and #t2, but |#t1 - #t2| == 1 remains true
    end

    -- apply changes:
    -- Gamerules:Jointeam(...)
    return t1, t2
end
---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------

-- Prepare team data for shuffling
local sampledata = require('sampledata')

local i_players = sampledata.s48 -- 10 marines, 20 aliens, 18 rr
--local i_players = sampledata.s44 -- 22 marines, 22 aliens, 00 rr
--local i_players = sampledata.s44_alien_max_2000 -- 22 marines, 22 aliens, max 2000 skill on alien
--local i_players = sampledata.s44_marine_max_2000 -- 22 marines, 22 aliens, max 2000 skill on marines
--local i_players = sampledata.s9 -- 5 marines, 4 aliens,
--local i_players = sampledata.s43 -- 22 marines, 21 aliens,
--local i_players = sampledata.s23 -- 12 marines, 11 aliens,

local maxPlayers = 44
local playerCount = #i_players
if (playerCount < maxPlayers) then
    maxPlayers = playerCount
end

assert(maxPlayers > 4)
local maxPlayersTeam = math.ceil(maxPlayers / 2)
-- t0 is non-afk ready room players
-- t1 is marines
-- t2 is alien
local teamMarine = getTeam(i_players, "marine", maxPlayersTeam)
local teamAlien = getTeam(i_players, "alien", maxPlayersTeam)
local teamNone = getTeam(i_players, "none")

showTeams(teamNone, teamMarine, teamAlien)

local t1, t2 = main(teamNone, teamMarine, teamAlien, maxPlayersTeam)


-- TODO Still need NOT to switch commanders, so implement tests not to move them
showTeams(teamNone, t1, t2)
