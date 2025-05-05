# script that writes co_chemsource subroutine from yaml file
# created with no love and absolutely no testing
# use at your own peril
# m.fabiani, 05/05/2025 ei fu siccome immobile

# no custom orders are implemented
# by default considers reactions as reversible, is forward you need backward rate to be 0

import cantera as ct 
from PiNeR import get, check_section

def find_indices(lst, condition):
   return [i for i, elem in enumerate(lst) if condition(elem)]

print()
print( ' ATLAS - Yaml To Fortran ' )
print( 'created with no love and absolutely no testing')
print()

# Input file definition
inifile = 'input.ini'
mech = get(file_path = inifile, section = 'YTF', option = 'mech', as_type = str)

infilename = mech+".yaml"
outfilename = mech+".f90"
mechname = mech

f = open(outfilename, "w")
f.write("subroutine "+mechname+"(roi,temp,omegadot,rotot)\n")
f.write("use MOSE_Global_m\n")
f.write("implicit none\n")
f.write("real(8), intent(in)  :: roi(nsc)\n")
f.write("real(8), intent(in)  :: temp\n")
f.write("real(8), intent(out) :: omegadot(nsc) \n")
f.write("real(8), intent(in)  :: rotot\n")

f.write('\n')
f.write('real(8) :: coi(nsc+1), Tdiff \n')
f.write('real(8) :: M !< Third body\n')
f.write('integer :: is, T_i, Tint(2)\n')


# get reaction list from cantera
all_species = ct.Species.list_from_file(infilename)
#species = all_species

gas = ct.Solution(infilename)
ref_phase = ct.Solution(thermo='ideal-gas', kinetics='gas', species=all_species)
all_reactions = ct.Reaction.list_from_file(infilename, ref_phase)
species = gas.species_names
nr = len(all_reactions)
f.write('real(8) :: prodf(1:'+str(nr)+'), prodb(1:'+str(nr)+')')
f.write('\n')
f.write('\n')


f.write('do is = 1, nsc \n')
f.write(' coi(is)=roi(is)/Wm_tab(is) ! kmol/m^3\n')  
f.write('enddo \n')
    
f.write('T_i = int(temp) \n')
f.write('Tdiff  = temp-T_i \n')
f.write('Tint(1) = T_i \n')
f.write('Tint(2) = T_i + 1 \n')
# writing of prodf and prodb
ir=0
for R in all_reactions:
  f.write('! reac n. '+str(ir+1)+': '+ str(R.equation)+'\n')
  string_reac='prodf('+str(ir+1)+')=comp_ch_tabT('+str(ir+1)+',kf_tab,Tint,Tdiff)'
  string_prod='prodb('+str(ir+1)+')=comp_ch_tabT('+str(ir+1)+',kb_tab,Tint,Tdiff)'

  for react in R.reactants:
    # for each reactant adds contribution to prodf
    ireact=find_indices(species, lambda e: e == react)
    ireact=ireact[0]
    ni = gas.reactant_stoich_coeff(react, ir)
    string_reac=string_reac+'*(coi('+str(ireact+1)+')**'+str(ni)+')'
    
  for prod in R.products:
    # for each product adds contribution to prodb
    iprod=find_indices(species, lambda e: e == prod)
    iprod=iprod[0]
    ni = gas.product_stoich_coeff(prod, ir)
    string_prod=string_prod+'*(coi('+str(iprod+1)+')**'+str(ni)+')'
    
  # Third body: for some reactions types this may not work... check!!!
  if (R.reaction_type=='three-body-Arrhenius'):
    string_reac=string_reac+'*M'
    string_prod=string_prod+'*M'
    
    # by default all species have efficiency 1
    if (len(R.third_body.efficiencies.keys())) > 0:
      Mstring='M=0.d0'
      for isp in range(0,len(species)):
        itb=find_indices(R.third_body.efficiencies.keys(), lambda e: e == species[isp])
        if (len(itb)>0) :
          eff=R.third_body.efficiency(species[isp])
        else:
          eff=1.0
          
        Mstring=Mstring+'+coi('+str(isp+1)+')'+'*'+str(eff) 

    else:
       
      Mstring='M=sum(coi(1:'+str(len(species))+'))'
    
    f.write(Mstring+'\n')
  elif (R.reaction_type=='falloff-Troe'):
    # nel caso di reazione di falloff mantengo per ora
    # stessa formulazione di three-body
    string_reac=string_reac+'*M'
    string_prod=string_prod+'*M'
    
    if (len(R.third_body.efficiencies.keys())) > 0:
      Mstring='M=0.d0'
      for isp in range(0,len(species)):
        itb=find_indices(R.third_body.efficiencies.keys(), lambda e: e == species[isp])
        if (len(itb)>0) :
          eff=R.third_body.efficiency(species[isp])
        else:
          eff=1.0
          
        Mstring=Mstring+'+coi('+str(isp+1)+')'+'*'+str(eff) 

    else:
       
      Mstring='M=sum(coi(1:'+str(len(species))+'))'
    
    f.write(Mstring+'\n')
  elif (R.reaction_type=='Arrhenius'):
    # non serve fare nulla  
    Mstring = ' '
    
  f.write(string_reac+'\n')
  f.write(string_prod+'\n')
  
  ir=ir+1

  
  
f.write('! species source terms\n')
isp=1
for spec in species:
  # check if species is present in at least one reaction
  present=False 
  for R in all_reactions:
    if (spec in R.reactants) or (spec in R.products):
      present=True
       
  if (present):
    string='omegadot('+str(isp)+')=Wm_tab('+str(isp)+')*('
    ir=0
    for R in all_reactions:
      if (spec in R.reactants) or (spec in R.products):
        nir = gas.reactant_stoich_coeff(spec, ir)
        nip = gas.product_stoich_coeff(spec, ir)
        string=string+'+('+str(nip)+'-'+str(nir)+')*(prodf('+str(ir+1)+')-prodb('+str(ir+1)+'))'

      ir=ir+1
    string=string+(')')
  else:
    string='omegadot('+str(isp)+')=0.d0'
    
  f.write(string+'\n')
  
  isp=isp+1
  
  
f.write('end subroutine '+mechname+'\n')