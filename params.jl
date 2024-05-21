# Parameters written by the user 
const fps = 100
const fps_logic = 100
const height = 800
const width = 1200
const n_lifts = 3
const n_floors = 8
const n_people = 300
const person_size = 15
const loading_time = 20 
const origin_prob::Array{Float64, 1} = [0.4, 0.1, 0.1, 0.1, 0.1, 0.1, 0.05, 0.05]
const destination_prob::Array{Float64, 1} = [0.4, 0.1, 0.1, 0.1, 0.1, 0.1, 0.05, 0.05]
const lift_step = 1
const interarrival = 600