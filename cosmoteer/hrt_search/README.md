# cosmo_hrt_search #
Tool for cosmoteer to find the optimal heat ray turret setup.
It optimises for output power within a given budget and specification. The calculator accounts for factors such as door and pipe cost, cooling costs, and aproximates the cost of power as 5.5k credit-seconds per battery. It does not account for the cost of mass.
The formulas for amplification and dialation are pulled directly from the game files. The aproximate cost of power was based on aproximations of reactor size and crew delivery costs, and should be representative of OMR / LR efficency. The factor of 1400 heat per 100% dialation arises from the base heat/tile of HRT impacts, and is aproximated from simulations of HRT impact on solid blocks of material, averaged over impact angles of +- 45 degrees and over dialation values of 50% to 1000%.

### Install and Compile ###
To run the program, install Love2d from https://love2d.org/#download or `love` from your package manager, then download and run `cosmo_hrt_search.love`.

to compile the program, install `love` and run `love ./src`
