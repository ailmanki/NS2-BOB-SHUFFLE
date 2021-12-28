local inspect = require('lib.inspect') -- load https://github.com/kikito/inspect.lua
if not os.execute("clear") then os.execute("cls") end -- Clear console
--------------------------------------------------

local ENUM_MARINE = 0
local ENUM_ALIEN = 1

local i_players = {
  {
    name = "Meteru",
    alien = 4000,
    marine = 3000
  },
  {
    name = "neo",
    alien = 5000,
    marine = 4000,
  },
  {
    name = "bob",
    alien = 2000,
    marine = 1000,
    },
  {
    name = "hannibal",
    alien = 3000,
    marine = 2000,
  },
  {
    name = "katzen",
    alien = 5000,
    marine = 5000,
  },
  {
    name = "noob",
    alien = 100,
    marine = 300,
  },
}

-- First step
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


-- Second Step
-- computes the variance of team members skills, using a previously computed mean(average) m
-- Use the classic variance definition from https://en.wikipedia.org/wiki/Variance
-- function taken from https://github.com/Bytebit-Org/lua-statistics/blob/master/src/statistics.lua#L119
local function variance(i_players, t_team, m_teamMean )
  local varianceSum = 0
  local count = #i_players
	for i = 1, count do
		local difference = i_players[i][t_team] - m_teamMean
		varianceSum = varianceSum + (difference * difference)
	end

	return varianceSum / count
end



-- Third step
-- computes the skewness of team members skills, using a previously computed mean and variance.
-- Use Fisher’s moment coefficient of skewness at https://en.wikipedia.org/wiki/ Skewness.
-- Avoid useless computations (mostly redundant divisions) by using the expanded formula
-- function taken https://github.com/tabacof/adversarial/blob/master/adversarial.lua#L364
local function skewness(i_players, t_team, m_teamAverage, v_teamVariance)
    local cube = 0
    local count = #i_players
    for i = 1, count do
        cube = cube + i_players[i][t_team] * i_players[i][t_team] * i_players[i][t_team]
    end
    cube = cube / count
    return (cube - 3 * m_teamAverage * v_teamVariance - m_teamAverage * m_teamAverage * m_teamAverage) / (math.sqrt(v_teamVariance) * v_teamVariance)
end

-- Fourth Step
-- computes a kind of relative gap between two values.
-- This function must return 0 if values are equal, it must get near 1 when values are different.
-- It must accounts for o negative values because skewness values can be negative and of opposite signs.
-- A proposed formula for such a function is:
-- relative(x,y) = |x−y| / |x|+|y|+|x+y|
-- I made it up to be able to 0compare moves later, check this choice on wolfram alpha for instance to get an
-- idea of how it works. In the case of the denominator being too small (< 10 −12 for instance); just
-- return 0 because it means that both values are really low and negligible for our purposes.

local abs = math.abs
local function relative(x, y)
  local denominator = abs(x) + abs(y) + abs(x + y)
  if 1e-12 < denominator then
    return abs(x - y) / denominator
  else
    return 0
  end
end

-- Fifth Step
-- computes a coefficient that gets higher the more the teams are unbalanced. 
-- The more the skill distributions are similar in terms of mean, variance, skewness (not necessarily normal
-- distribution, simply alike), the lower the coefficient gets.
--
-- This function will be used to choose what player swaps/switches to make later on.
-- Its results is between 0 (perfect equality) and 3 (worst case). 
-- In theory, returning only relative(s1,s2) should work to choose moves that can
-- balance teams because it contains the mean and variance. But for safety, we
-- put an emphasis on balance average skill and variance on their own.
local function asymmetry(teams)
  local m1 = mean(i_players, "marine")
  local m2 = mean(i_players, "alien")
  local v1 = variance(i_players, "marine", m1)
  local v2 = variance(i_players, "alien", m2)
  local s1 = skewness(i_players, "marine", m1, v1)
  local s2 = skewness(i_players, "alien", m2, v2)
  return relative(m1, m2) + relative(v1, v2) + relative(s1, s2)
end

-- Sixth Step
-- takes non-afk ready room players and fills up the teams if these are not full already. Loop over available
-- ready room players and evaluate asymmetry(t 1 ,t 2 ) with the added player to
-- the team with fewer players. Once all possible picks have been evaluated, apply
-- the best one, the one that minimizes asymmetry. Keep doing that until teams
-- are full or no players are available.
-- This step is ignore

-- Seventh Step
-- It must basically keep swapping players between teams until no better swap is found.
-- So it has three nested loops, an external while loop, and two internal for
-- loops over t 1 and t 2 respectively. Inside the nested for loops, try swapping two
-- players and evaluate asymmetry(t 1 ,t 2 ) with the new teams. Once all possible
-- swaps have been evaluated, apply the best one, the one minimizing asymmetry.
-- Break off the while loop once no better swap can be found.
local function swap(t1 ,t2 )
    local iter = 0
    local old_asym = "todo"
    local new_asym = -1 -- impossible ideal initial value to initialize
    -- for safety : iter < 100 useless if well implemented
    -- we try to make swaps as long as we can better balance the teams
    local count1 = "todo" -- players in team1
    local count2 = "todo" -- players in team2 (actually same as team 1)
    -- iter < 100 
    while (iter < 100 and new_asym < old_asym) do -- while we 
        new_asym = asymmetry("todo") -- current asymmetry level ( between 0 and 3)
        old_asym = new_asym
        local i_index = -1 -- impossible initial index
        local j_index = -1 -- impossible initial index
        for i = 1, count1 do -- loop over team 1 players
            for j = 1, count2 do -- loop over team 2 players
                -- try to swap players i and j from teams 1 and teams 2
                -- recompute asymmetry of the teams with the swapped players to see if it’s lower
                local asym = asymetry("todo")
                if asym < new_asym then -- if we found a lower asym we save the swap to make to get it
                    new_asym = asym
                    i_index = i
                    j_index = j
                end
                -- restore the teams to their original state to try better moves
            end
        end
        -- now apply the best swap that was saved to the list and loop over until you can’t find a better one
        -- by applying best moves we avoid switching too many players
        iter = iter + 1 
    end
    return -- the updated teams
end

local m_marineMean = mean(i_players, "marine")
local m_alienMean = mean(i_players, "alien")
local v_marineVariance = variance(i_players, "marine", m_marineMean)
local v_alienVariance = variance(i_players, "alien", m_alienMean)
local v_marineSkewness = skewness(i_players, "marine", m_marineMean, v_marineVariance)
local v_alienSkewness = skewness(i_players, "alien", m_alienMean, v_alienVariance)

local asymmetryTeams = asymmetry(i_players)


print("i_players: " .. inspect(i_players))
print("m_marineMean: " .. inspect(m_marineMean))
print("m_alienMean: " .. inspect(m_alienMean))

print("v_marineVariance: " .. inspect(v_marineVariance))
print("v_alienVariance: " .. inspect(v_alienVariance))


print("v_marineSkewness: " .. inspect(v_marineSkewness))
print("v_alienSkewness: " .. inspect(v_alienSkewness))

print("asymmetryTeams: " .. inspect(asymmetryTeams))