
def extract(models,solutions):
    
    Ta = {}
    for model in models:
        Ta[model] = []
        for sol in solutions[model]:
            Ta[model].append(sol.T)

    if len(models)==1:
        if len(solutions[models[0]])==1:
            print(solutions[models[0]][0].T)
            for s in range(solutions[models[0]][0].n_species):
                print(solutions[models[0]][0].species_names[s],solutions[models[0]][0][s].Y[0])
            return None

    return Ta