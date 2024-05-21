using ResumableFunctions
using Colors
using StatsBase
using DataStructures
using GameZero

game_include("params.jl")

# Dev Note: x -> horizontal/width, y -> vertical/height


# Parameters computed
const BACKGROUND = "background.jpeg"
const HEIGHT = height       
const WIDTH = width

const size = (width * 2, height * 2)
const wsize = (width * 2 * 0.8, height * 2 * 0.8)
const wpos = (width * 2 * 0.1, height * 2 * 0.1)
const floor_width = wsize[1]
const floor_height = floor(Int64, wsize[2] / n_floors)
const lift_space_height = floor_height
const lift_space_width = floor(Int64, wsize[1] / (2 * n_lifts))
const lift_height = floor(Int64, floor_height * 0.9)
const lift_width = floor(Int64, 0.9 * wsize[1] / (2 * n_lifts))
const person_space_size = person_size * 1.1
const max_people_floor = (floor(Int64, (floor_width / 2) / person_space_size), floor(Int64, floor_height / person_space_size))
const max_people_lift = (floor(Int64, lift_width / person_space_size), floor(Int64, lift_height / person_space_size))

macro checks()
    @assert sum(origin_prob) == 1.0 "Sum of origin floor probabilities should be 1"
    @assert sum(destination_prob) == 1.0 "Sum of destination floor probabilities should be 1"
    @assert n_floors == length(origin_prob) "Origin floor probabilities should be equal to number of floors"
    @assert n_floors == length(destination_prob) "Destination floor probabilities should be equal to number of floors"
end

@checks

macro expovariate()
    return :(log(1.0 - rand()) / (-1 / $interarrival))
end

function roulette_wheel(probs::Array{Float64, 1})::Int64 
    cum::Float64 = 0.0 
    rnd = rand()
    for i in 1:length(probs) 
        cum += probs[i]
        if cum > rnd return i end
    end
    return length(probs)
end

@enum Direction up down 

@kwdef mutable struct Person 
    id::Int64
    origin::Int64 
    destination::Int64
    creation::Float64 
    entry::Float64 = 0
    exit::Float64 = 0
    in_simulation::Bool = false
    in_lift::Bool = false 
    lift::Int64 = -1
end

@kwdef mutable struct Lift 
    id::Int64
    pos::Tuple{Float64, Float64}
    origin::Int64 = 0
    destionation::Int64 = 0
    people::Array{Person, 1} = []
end

function get_direction(lift::Lift)::Direction
    return Direction.up ? lift.origin < lift.destionation : Direction.down
end

function get_floor(lift::Lift)::Int64 
    @assert lift.pos[2] >= wpos[2] && lift.pos[2] <= wpos[2] + wsize[2]
    return Int64(floor( (lift.pos[2] - wpos[2]) / floor_height))
end

function is_at_floor(lift::Lift)::Bool 
    return true
end

@resumable function source()::Person 
    i::Int64 = 0 
    last_creation::Float64 = 0.0 
    creation::Float64 = 0.0
    for i in 1:n_people
        add_time = @expovariate
        creation = i == 1 ? 0.0 : last_creation + add_time
        origin = roulette_wheel(origin_prob)
        destination = roulette_wheel(destination_prob)
        while origin == destination 
            origin = roulette_wheel(origin_prob)
            destination = roulette_wheel(destination_prob)
        end
        @yield Person(
            id=i, 
            creation=creation, 
            origin=origin, 
            destination=destination
        )
        i += 1
        last_creation = creation
    end
end

# Main elements
sim_time::Int64 = 0
last_logic_step::Int64 = 0
floor_to_people = DefaultDict(0, Dict{Int64, Int64}())
lift_to_people = DefaultDict(0, Dict{Int64, Int64}())
lifts::Array{Lift} = [
    Lift(
        id=i, 
        pos=( floor(wpos[1] + wsize[1] / 2 + 0.05 * lift_space_width + (i-1) * lift_space_width), 
              floor(wpos[2] + lift_space_height * (n_floors - 1) + lift_space_height * 0.05) )
) for i in 1:n_lifts]

generator = source()
persons::Array{Person} = [] 
person::Union{Person, Nothing} = nothing
exit_persons_counter::Int64 = 0
exit_logged::Bool = false

function logic_step()
end


# Simulation step
function update(g::Game)
    global last_logic_step, sim_time, n_people, generator, person, persons, exit_persons_counter, floor_to_people, lift_to_people, exit_logged

    # simulation finished
    if exit_persons_counter == n_people return end

    # update time
    sim_time += fps

    # check if last generatd person can enter the simulation 
    if person !== nothing && person.creation < sim_time && person.in_simulation == false
        person.in_simulation = true
        push!(persons, person)
        floor_to_people[person.origin] += 1
        creation_print = floor(person.creation)
        n_total_people = length(persons)
        println("[$sim_time] Person created at $creation_print entered the simulation ($n_total_people people in simulation).")
    end

    # generate person 
    if length(persons) < n_people && (person === nothing || person.in_simulation)
        person = generator()
    elseif exit_logged == false && length(persons) == n_people
        println("[$sim_time] Maximum of people reached.")
        exit_logged = true
    end

    # logic step 
    if sim_time - last_logic_step > fps_logic
        logic_step()
        last_logic_step = sim_time
    end


end

# Drawing step
function draw(g::Game)
    # draw field 
    draw(Rect(wpos[1], wpos[2], wsize[1], wsize[2]), RGBA{Float64}(1, 1, 1, 0.7), fill=true)
    # draw floors 
    for i in 1:(n_floors + 1)
        draw(Line(wpos[1], floor(wpos[2] + (i-1) * floor_height), wpos[1] + wsize[1], floor(wpos[2] + (i-1) * floor_height)))
    end
    # draw elevators
    for lift in lifts
        draw(Rect(lift.pos[1], lift.pos[2], lift_width, lift_height), RGBA{Float64}(0, 0, 1, 0.2), fill=true)
    end
    # draw waiting people 
    radius = floor(person_size / 2)
    for (floor_id, n) in floor_to_people
        n_width, n_height = 0, 0
        for _ in 1:n
            ypos = floor(Int64, wpos[2] + floor_height * (n_floors + 1 - floor_id ) - (n_height * person_space_size) - person_space_size / 2)
            xpos = floor(Int64, wpos[1] + floor_width / 2 - n_width * person_space_size - person_space_size / 2)
            draw(Circle(xpos, ypos, radius), RGB{Float64}(1, 0, 0), fill=true)
            n_width += 1
            if n_width >= max_people_floor[1] 
                n_width = 0
                n_height += 1
            end 
            if n_height >= max_people_floor[2] 
                break 
            end
        end
    end

    # draw people in lifts
    radius = floor(person_size / 2)
    for (lift_id, n) in lift_to_people
        n_width, n_height = 0, 0
        lift = lifts[lift_id] 
        @assert lift.id == lift_id "Something wrong happened to lifts sortation."
        for _ in 1:n 
            xpos = lift.pos[1] + n_width * person_space_size + person_space_size / 2
            ypos = lift.pos[2] + n_height * person_space_size + person_space_size / 2
            draw(Circle(xpos, ypos, radius), RGB{Float64}(1, 0, 0), fill=true)
            n_width += 1
            if n_width >= max_people_lift[1] 
                n_width = 0
                n_height += 1
            end 
            if n_height >= max_people_lift[2] 
                break 
            end
        end
    end
end
