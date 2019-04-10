using Util

include("world_util.jl")


# a piece of knowledge an agent has about a location
mutable struct InfoLocationT{L}
	pos :: Pos
	id :: Int
	# property values the agent expects
	resources :: TrustedF
	quality :: TrustedF

	links :: Vector{L}
end

mutable struct InfoLink
	id :: Int
	l1 :: InfoLocationT{InfoLink}
	l2 :: InfoLocationT{InfoLink}
	friction :: TrustedF
end

const InfoLocation = InfoLocationT{InfoLink}

const Unknown = InfoLocation(Nowhere, 0, TrustedF(0.0), TrustedF(0.0), [])
const UnknownLink = InfoLink(0, Unknown, Unknown, TrustedF(0.0))


resources(l :: InfoLocation) = l.resources.value
quality(l :: InfoLocation) = l.quality.value
friction(l :: InfoLink) = l.friction.value


otherside(link, loc) = loc == link.l1 ? link.l2 : link.l1

# no check for validity etc.
add_link!(loc, link) = push!(loc.links, link)


# migrants
mutable struct AgentT{L}
	# current real position
	loc :: L
	in_transit :: Bool
	# next step, could be L but this is easier
	next :: InfoLocation
	# what it thinks it knows about the world
	n_locs :: Int
	info_loc :: Vector{InfoLocation}
	n_links :: Int
	info_link :: Vector{InfoLink}
	# abstract capital, includes time & money
	capital :: Float64
	# people at home & in target country, other migrants
	contacts :: Vector{AgentT{L}}
	steps :: Int
end

AgentT{L}(l::L, c :: Float64) where {L} = AgentT{L}(l, true, Unknown, 0, [],  0, [], c, [], 0)


arrived(agent) = agent.loc.typ == EXIT


function add_info!(agent, info :: InfoLocation, typ = STD) 
	@assert agent.info_loc[info.id] == Unknown
	agent.n_locs += 1
	agent.info_loc[info.id] = info
end

function add_info!(agent, info :: InfoLink) 
	@assert agent.info_link[info.id] == UnknownLink
	agent.n_links += 1
	agent.info_link[info.id] = info
end

function add_contact!(agent, a)
	if a in agent.contacts
		return
	end

	push!(agent.contacts, a)
end


@enum LOC_TYPE STD=1 ENTRY EXIT

mutable struct LocationT{L}
	id :: Int
	typ :: LOC_TYPE
	resources :: Float64
	quality :: Float64
	people :: Vector{AgentT{LocationT{L}}}

	links :: Vector{L}

	pos :: Pos

	count :: Int
end


distance(l1, l2) = distance(l1.pos, l2.pos)

@enum LINK_TYPE FAST=1 SLOW

mutable struct Link
	id :: Int
	typ :: LINK_TYPE
	l1 :: LocationT{Link}
	l2 :: LocationT{Link}
	friction :: Float64
	distance :: Float64
	count :: Int
end


Link(id, t, l1, l2) = Link(id, t, l1, l2, 0, 0, 0)


LocationT{L}(p :: Pos, t, i) where {L} = LocationT{L}(i, t, 0.0, 0.0, [], L[], p, 0)
# construct empty location
#LocationT{L}() where {L} = LocationT{L}(Nowhere, STD, 0)

const Location = LocationT{Link}

const Agent = AgentT{Location}

# get the agent's info on a location
info(agent, l::Location) = agent.info_loc[l.id]
# get the agent's info on its current location
info_current(agent) = info(agent, agent.loc)
# get the agent's info on a link
info(agent, l::Link) = agent.info_link[l.id]

known(l::InfoLocation) = l != Unknown
known(l::InfoLink) = l != UnknownLink

# get the agent's info on a location
knows(agent, l::Location) = known(info(agent, l))
# get the agent's info on a link
knows(agent, l::Link) = known(info(agent, l))

function find_link(from, to)
	for l in from.links
		if otherside(l, from) == to
			return l
		end
	end

	nothing
end


mutable struct World
	cities :: Vector{Location}
	links :: Vector{Link}
	entries :: Vector{Location}
	exits :: Vector{Location}
end

World() = World([], [], [], [])



remove_agent!(loc::Location, agent::Agent) = drop!(loc.people, agent)


function add_agent!(loc::Location, agent::Agent) 
	push!(loc.people, agent)
	loc.count += 1
end


remove_agent!(world, agent) = remove_agent!(agent.loc, agent)


function move!(world, agent, loc)
	remove_agent!(world, agent)
	agent.loc = loc
	add_agent!(loc, agent)
end


