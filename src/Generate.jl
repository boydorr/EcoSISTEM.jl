using StatsBase
using ProgressMeter

# Function to randomly populate a habitat matrix
function populate(species::Int64, individuals::Int64, habitat::Habitats,
   dist::Distribution= Multinomial(individuals,species))
  # Calculate size of habitat
  dim=size(habitat.matrix)
  # Create empty population matrix of correct dimensions
  P=zeros(Int64,species,dim[1],dim[2])
  # Randomly choose abundances for each species from Multinomial
  abun_vec=rand(dist)
  # Loop through species
  for i in eachindex(abun_vec)
    # Get abundance of species
    abun=abun_vec[i]
      # Loop through individuals
      while abun>0
      # Randomly choose position on grid
      x=rand(1:dim[1])
      y=rand(1:dim[1])
      # Add individual to this location
      P[i,x,y]=P[i,x,y]+1
      abun=abun-1
    end
  end
  # Create MatrixLandscape from P matrix and habitat
  MatrixLandscape(P, habitat)
end

# Function to calculate species richness from an Ecosystem object
function SR(ecosystem::Ecosystem)
  sz=size(ecosystem.partition.abundances,2,3)
  ms=map(x-> sum(ecosystem.partition.abundances[:,x].>0), 1:(sz[1]*sz[2]))#*individuals
  reshape(ms, sz)
end

# Function to create a habitat from a discrete set of types
function create_habitat(dim, types, prop)
  # Weighted sample from the types in the correct dimension
  sample(types, WeightVec(prop), dim)
end

# Function to create a habitat from a discrete set of types according to the
# Saura-Martinez-Millan algorithm (2000)
function percolate!(M::AbstractMatrix, p::Real)
  for i in 1:(length(M))
    if junif(0, 1) < p
      M[i]=1
    end
  end
end

# Function to create clusters from percolated grid
function identify_clusters!(M::AbstractMatrix)
  dim=size(M)
  # Begin cluster count
  count=1
  # Loop through each grid square in M
  for x in 1:dim[1]
    for y in 1:dim[2]

      # If square is marked as 1, then apply cluster finding algorithm
      if M[x,y]==1.0
        # Find neighbours of M at this location
        neighbours=get_neighbours(M, y, x)
        # Find out if any of the neighbours also have a value of 1, thus, have
        # not been assigned a cluster yet
        cluster = vcat(mapslices(x->M[x[1],x[2]].==1, neighbours, 2)...)
        # Find out if any of the neighbours have a value > 1, thus, have already
        # been assigned a cluster
        already=vcat(mapslices(x->M[x[1],x[2]].>1, neighbours, 2)...)
        # If any already assigned neighbours, then assign the grid square to this
        # same type
          if any(already)
            neighbours=neighbours[already,:]
            M[x,y]=M[neighbours[1,1],neighbours[1,2]]
          # If none are assigned yet, then create a new cluster
          else
            count=count+1
            neighbours=neighbours[cluster,:]
            M[x,y]=count
            map(i->M[neighbours[i,1],neighbours[i,2]]=count, 1:size(neighbours,1))
        end
      end
    end
  end
end

function fill_in!(T, M, types, wv)
  dim = size(M)
  # Loop through grid of clusters
  for x in 1:dim[1]
    for y in 1:dim[2]
      # If square is zero then it is yet to be assigned
      if M[x,y]==0
        # Find neighbours of square on string grid
        neighbours=get_neighbours(T, y, x, 8)
        # Check if they have already been assigned
        already=vcat(mapslices(x->isdefined(T,x[1],x[2]), neighbours, 2)...)
        # If any already assigned then sample from most frequent neighbour traits
          if any(already)
            neighbours=neighbours[already,:]
            # Find all neighbour traits
            neighbour_traits=map(i->T[neighbours[i,1],neighbours[i,2]],
             1:size(neighbours,1))
             # Find which one is counted most often
            ind=indmax(map(x->sum(neighbour_traits.==x), types))
            # Assign this type to the grid square in T
            T[x,y]= types[ind]
          # If none are assigned in entire grid already,
          # sample randomly from traits
        elseif all(M.<=1)
            T[x,y]=sample(types, wv)
          # If some are assigned in grid, sample from these
          else
            T[x,y]=sample(T[M.>1])
        end
      end
    end
  end
end

 function random_habitat(dim::Tuple, types, p::Real, A::Vector)
  # Check that the proportion of coverage for each type matches the number
  # of types and that they add up to 1
  length(A)==length(types) || error("There must be an area proportion for each type")
  sum(A)==1 || error("Proportion of habitats must add up to 1")
  # Create weighting from proportion habitats
  wv=weights(A)

  # Create an empty grid of the right dimension
  M=zeros(dim)

  # If the dimensions are too small for the algorithm, just use a weighted sample
  if any(map(x-> dim[x]<=2, 1:2))
    T = create_habitat(dim, types, A)
  else
    # Percolation step
    percolate!(M, p)
    # Select clusters and assign types
    identify_clusters!(M)
    # Create a string grid of the same dimensions
    T=Array{String}(dim)
    # Fill in T with clusters already created
    map(x->T[M.==x]=sample(types, wv), 1:maximum(M))
    # Fill in undefined squares with most frequent neighbour
    fill_in!(T, M, types, wv)
    T
  end
end

# Function to populate a Niche habitat
function populate(species::Int64, individuals::Int64, habitat::Niches,
  traits::Vector, budget::Budget,
  dist::Distribution= Multinomial(individuals,species))
  # Calculate size of habitat
  dim=size(habitat.matrix)
  grid=collect(1:dim[1]*dim[2])
  # Create empty population matrix of correct dimensions
  P=zeros(Float64,species,dim[1],dim[2])
  # Randomly choose abundances for each species from Multinomial
  abun_vec=rand(dist)
  # Set up copy of budget
  b=copy(budget.matrix)
  # Loop through species
  for i in eachindex(abun_vec)
    # Get abundance of species
    abun=abun_vec[i]
    # Get species trait
    pref=traits[i]
    # Calculate weighting, giving preference to squares that match with trait
    wv= Vector{Float64}(grid)
    wv[find(reshape(habitat.matrix, (dim[1]*dim[2],1))[grid].==pref)]= 0.9
    wv[find(reshape(habitat.matrix, (dim[1]*dim[2],1))[grid].!=pref)]= 0.1
    # Loop through individuals
      while abun>0
        zs=findin(b[grid], 0)
        deleteat!(grid, zs)
        deleteat!(wv, zs)
        # Randomly choose position on grid (weighted)
      pos=sample(grid, weights(wv))
      # Add individual to this location
      P[i,pos]=P[i,pos]+1
      abun=abun-1
      b[pos]=b[pos]-1
    end
    #sum_abun=mapslices(sum, P, 1)[1,:,:]
    #@rput(sum_abun)
    #R"par(mfrow=c(1,2));image.plot(sum_abun,col=rainbow(50)[1:20], breaks=seq(0,20,1));image(hab, legend = F)"
  end
  # Create MatrixLandscape from P matrix and habitat
  MatrixLandscape(P, habitat, budget)
end


# Function to get the neighbours of a grid square in a matrix in 4 or 8 directions
function get_neighbours(mat::Matrix, x_coord::Int64, y_coord::Int64, chess::Int64=4)
  # Calculate dimensions
  dims=size(mat)
  x_coord <= dims[1] && y_coord <= dims[2] || error("Coordinates outside grid")
  # Include 4 directions
  if chess==4
    neighbour_vec=[x_coord y_coord-1; x_coord y_coord+1; x_coord-1 y_coord;
     x_coord+1 y_coord]
  # Include 8 directions
  elseif chess==8
    neighbour_vec=[x_coord y_coord-1; x_coord y_coord+1; x_coord-1 y_coord;
     x_coord+1 y_coord; x_coord-1 y_coord-1; x_coord-1 y_coord+1;
      x_coord+1 y_coord-1; x_coord+1 y_coord+1]
  else
    # Give error if other number chosen than 4 or 8
    error("Can only calculate neighbours in 4 or 8 directions")
  end
  # Remove answers outside of the dimensions of the matrix
  remove=vcat(mapslices(all, [neighbour_vec.>=1 neighbour_vec[:,1].<=
    dims[1] neighbour_vec[:,2].<=dims[2]], 2)...)
  neighbour_vec=neighbour_vec[remove,:]
  neighbour_vec
end

# Function to update a Ecosystem after one timestep- stochastic birth, death and movement
function update!(eco::Ecosystem,  birth::Float64, death::Float64, move::Float64,
   l::Float64, s::Float64, timestep::Real)

   # For now keep l>s
   l > s || error("l must be greater than s")
   l >= 0 && s >= 0 || error("l and s must be greater than zero")

  # Calculate abundance in overall grid (to be implemented later?)
  #abun=map(i->sum(eco.partition.abundances[i,:,:]), 1:size(eco.partition.abundances,1))

  # Calculate dimenions of habitat and number of species
  dims = size(eco.partition.abundances)[2:3]
  spp = size(eco.partition.abundances,1)
  net_migration = zeros(size(eco.partition.abundances))

  # Loop through grid squares
  for x in 1:dims[1]
    for y in 1:dims[2]

      # Get the overall energy budget of that square
      K = eco.abenv.budget.matrix[x, y]
      randomise=collect(1:spp)
      randomise=randomise[randperm(length(randomise))]
      # Loop through species in chosen square
      for j in randomise

        # Get abundances of square we are interested in
        square = eco.partition.abundances[:,x, y]

        if square[j] <= 0
          eco.partition.abundances[j,x, y] = 0
        else
        # Get energy budgets of species in square
        ϵ̄ = eco.spplist.energy.energy
        E = sum(square .* ϵ̄)

        # Alter rates by energy available in current pop & own requirements
        birth_energy = (ϵ̄[j])^(-l-s) * K / E
        death_energy = (ϵ̄[j])^(-l+s) * E / K

        # Calculate effective rates
        birthprob = birth * timestep * birth_energy
        deathprob = death * timestep * death_energy

        # If traits are same as habitat type then give birth "boost"
        #if eco.spplist.traits.traits[j] != eco.abenv.habitat.matrix[x, y]
        #  birthrate = birthrate * 0.8
        #end

        # If zero abundance then go extinct
        if square[j] == 0
          birthprob = 0
          deathprob = 0
        end

        # Throw error if rates exceed 1
        #birthprob <= 1 && deathprob <= 1 && moveprob <= 1 ||
        #  error("rates larger than one in binomial draw")


        # Put probabilities into 0 - 1
        probs = map(prob -> 1-exp(-prob), [birthprob, deathprob])

        # Calculate how many births and deaths
        births = jbinom(1, Int(square[j]), probs[1])[1]
        deaths = jbinom(1, Int(square[j]), probs[2])[1]

        # Update population
        eco.partition.abundances[j, x, y] = eco.partition.abundances[j, x, y] +
          births - deaths

        # Then calculate movements
        square[j] = eco.partition.abundances[j, x, y]

        # Perform gaussian movement
        move!(x, y, j, eco, net_migration)
        end
      end
    end
  end
  eco.partition.abundances = eco.partition.abundances .+ net_migration
end
function update_birth_move!(eco::Ecosystem,  birth::Float64, death::Float64, move::Float64,
   l::Float64, s::Float64, timestep::Real)

   # For now keep l>s
   l > s || error("l must be greater than s")
   l >= 0 && s >= 0 || error("l and s must be greater than zero")

  # Calculate abundance in overall grid (to be implemented later?)
  #abun=map(i->sum(eco.partition.abundances[i,:,:]), 1:size(eco.partition.abundances,1))

  # Calculate dimenions of habitat and number of species
  dims = size(eco.partition.abundances)[2:3]
  spp = size(eco.partition.abundances,1)
  net_migration = zeros(size(eco.partition.abundances))

  # Loop through grid squares
  for x in 1:dims[1]
    for y in 1:dims[2]

      # Get the overall energy budget of that square
      K = eco.abenv.budget.matrix[x, y]
      randomise=collect(1:spp)
      randomise=randomise[randperm(length(randomise))]
      # Loop through species in chosen square
      for j in randomise

        # Get abundances of square we are interested in
        square = eco.partition.abundances[:,x, y]

        if square[j] <= 0
          eco.partition.abundances[j,x, y] = 0
        else
        # Get energy budgets of species in square
        ϵ̄ = eco.spplist.energy.energy
        E = sum(square .* ϵ̄)

        # Alter rates by energy available in current pop & own requirements
        birth_energy = (ϵ̄[j])^(-l-s) * K / E
        death_energy = (ϵ̄[j])^(-l+s) * E / K
        move_energy = 1

        # Calculate effective rates
        birthprob = birth * timestep * birth_energy
        deathprob = death * timestep * death_energy
        moveprob = move * timestep * move_energy

        # If traits are same as habitat type then give birth "boost"
        #if eco.spplist.traits.traits[j] != eco.abenv.habitat.matrix[x, y]
        #  birthrate = birthrate * 0.8
        #end

        # If zero abundance then go extinct
        if square[j] == 0
          birthprob = 0
          deathprob = 0
          moveprob = 0
        end

        # Throw error if rates exceed 1
        #birthprob <= 1 && deathprob <= 1 && moveprob <= 1 ||
        #  error("rates larger than one in binomial draw")


        # Put probabilities into 0 - 1
        probs = map(prob -> 1-exp(-prob), [birthprob, deathprob])

        # Calculate how many births and deaths
        births = jbinom(1, Int(square[j]), probs[1])[1]
        deaths = jbinom(1, Int(square[j]), probs[2])[1]

        # Update population
        eco.partition.abundances[j, x, y] = eco.partition.abundances[j, x, y] +
          births - deaths

        moves = jbinom(1, Int(births), moveprob)[1]

        # Update population
        net_migration[j, x, y] = net_migration[j, x, y] - moves
        if (moves>0)
        # Find neighbours of grid square
          neighbours = get_neighbours(eco.abenv.habitat.matrix, x, y)
        # Randomly sample one of the neighbours
          choose = rand(Multinomial(moves, size(neighbours, 1)))
         for k in eachindex(choose)
              destination = neighbours[k, :]
          # Add one to this neighbour
             net_migration[j, destination[1], destination[2]] =
                net_migration[j, destination[1], destination[2]] + choose[k]
            end
         end
        end
      end
    end
  end
  eco.partition.abundances = eco.partition.abundances .+ net_migration
end


# Alternative populate function
function populate!(ml::AbstractStructuredPartition, spplist::SpeciesList,
                   abenv::AbstractAbiotic, traits::Bool)
  # Calculate size of habitat
  dim=size(abenv.habitat.matrix)
  grid=collect(1:dim[1]*dim[2])
  # Set up copy of budget
  b=copy(abenv.budget.matrix)
  # Loop through species
  for i in eachindex(spplist.abun)
    # Get abundance of species
    abun=spplist.abun[i]
    # Get species trait
    pref=spplist.traits.traits[i]
    # Calculate weighting, giving preference to squares that match with trait
    wv= Vector{Float64}(grid)
    wv[find(reshape(abenv.habitat.matrix, (dim[1]*dim[2],1))[grid].==pref)]= 0.5
    wv[find(reshape(abenv.habitat.matrix, (dim[1]*dim[2],1))[grid].!=pref)]= 0.5
    # Loop through individuals
      while abun>0
        zs=findin(b[grid], 0)
        deleteat!(grid, zs)
        deleteat!(wv, zs)
        # Randomly choose position on grid (weighted)
        if traits pos=sample(grid, weights(wv)) else pos=sample(grid) end
      # Add individual to this location
      ml.abundances[i,pos]=ml.abundances[i,pos]+1
      abun=abun-1
      b[pos]=b[pos]-1
    end
  end
end

# add in draw from multinomial
function populate!(eco::Ecosystem, traits::Bool)
  # Calculate size of habitat
  eco.partition.abundances = zeros(size(eco.partition.abundances))
  dim=size(eco.abenv.habitat.matrix)
  grid=collect(1:dim[1]*dim[2])
  # Set up copy of budget
  b=copy(eco.abenv.budget.matrix)
  # Loop through species
  eco.spplist.abun = rand(Multinomial(sum(eco.spplist.abun), length(eco.spplist.abun)))
  for i in eachindex(eco.spplist.abun)
    # Get abundance of species
    abun=eco.spplist.abun[i]
    # Get species trait
    pref=eco.spplist.traits.traits[i]
    # Calculate weighting, giving preference to squares that match with trait
    wv= Vector{Float64}(grid)
    wv[find(reshape(eco.abenv.habitat.matrix, (dim[1]*dim[2],1))[grid].==pref)]= 0.5
    wv[find(reshape(eco.abenv.habitat.matrix, (dim[1]*dim[2],1))[grid].!=pref)]= 0.5
    # Loop through individuals
      while abun>0
        zs=findin(b[grid], 0)
        deleteat!(grid, zs)
        deleteat!(wv, zs)
        # Randomly choose position on grid (weighted)
        if traits pos=sample(grid, weights(wv)) else pos=sample(grid) end
      # Add individual to this location
      eco.partition.abundances[i,pos]=eco.partition.abundances[i,pos]+1
      abun=abun-1
      b[pos]=b[pos]-1
    end
  end
end



function run_sim(eco, params::AbstractVector, times::Int64, reps::Int64)

  birth = param[1]
  death = param[2]
  move = param[3]
  timestep = param[4]
  l = param[5]
  s = param[6]

  gridSize = grid[1] *  grid[2]
  abun = zeros(times+1, numSpecies, gridSize, reps); ener = zeros(times+1, gridSize, reps)

  for j in 1:reps

    populate!(eco, false)

    for k in 1:gridSize
      abun[1,:, k,  j] = eco.partition.abundances[:, 1]
      ener[1, k,  j] = sum(eco.spplist.abun .* eco.spplist.energy.energy)
    end

    for i in 1:times
        update!(eco, birth, death, move, l, s, timestep)
        for g in 1:gridSize
          abun[i+1, :,g, j] = eco.partition.abundances[: , g]
          ener[i+1, g, j] = sum(eco.partition.abundances[: , g] .* eco.spplist.energy.energy)
        end
    end
    map
  end
  mean_abun = mapslices(mean, abun, 4)
  sd_abun = mapslices(std, abun, 4)
  mean_ener = mapslices(mean, ener, 3)
  sd_ener = mapslices(std, ener, 3)
  [abun, mean_abun, sd_abun, mean_ener, sd_ener]
end

function run_sim_spatial(eco::Ecosystem, params::AbstractVector,
   times::Int64, burnin::Int64, interval::Int64, reps::Int64, birth_move::Bool)

  birth = param[1]
  death = param[2]
  move = param[3]
  timestep = param[4]
  l = param[5]
  s = param[6]
  time_seq = collect(burnin:interval:times)
  gridSize = grid[1] *  grid[2]
  abun = zeros(length(time_seq)+1, numSpecies, reps, gridSize); ener = zeros(length(time_seq)+1, reps)

  if birth_move
    update_fun=update_birth_move!
  else
    update_fun=update!
  end

  @showprogress 1 "Computing..." for j in 1:reps
    populate!(eco, false)

    abun[1, :, j, :] = eco.partition.abundances[:, :]
    counting = 1
    for i in 1:times
        update_fun(eco, birth, death, move, l, s, timestep); #print(eco.partition.abundances)
        if any(i.==time_seq)
            counting = counting+1
            abun[counting, :, j, :] = eco.partition.abundances[: , :]
      end
    end
  end
  abun
end
