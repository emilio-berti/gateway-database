##############################
## database reformating ######
##############################

library(dplyr)
library(tidyr)

# questions:
# species$taxonomicLevel and species$taxonRank seems equivalent: doublons?

species_old = read.csv('~/projects/Gateway2/gateway-database/data/species.csv')
interactions_old = read.csv('~/projects/Gateway2/gateway-database/data/interactions.csv')
foodwebs_old = read.csv('~/projects/Gateway2/gateway-database/data/foodwebs.csv')


###### create peripheric tables with no foreign keys ########

# reference table
list.refs = unique(c(species_old$sizeReference, interactions_old$interactionReference))
references = data.frame(referenceID = 1:length(list.refs),
                        reference = list.refs)
# head(references)
rm(list.refs)

# life stage table
stages = unique(species_old$lifeStage)
life_stages = data.frame(lifeStageID = 1:length(stages),
                         lifeStage = stages)
rm(stages)

# size methods
sizemet = unique(species_old$sizeMethod)
size_methods = data.frame(sizeMethodID = 1:length(sizemet),
                          sizeMethod = sizemet)
rm(sizemet)

# mouvement types
mov = unique(species_old$movementType)
movement_types = data.frame(movementTypeID = 1:length(mov),
                            movementType = mov)
rm(mov)

# metabolic types
mets = unique(species_old$metabolicType)
metabolic_types = data.frame(metabolicTypeID = 1:length(mets),
                             metabolicType = mets)
rm(mets)

# interaction types
ints = unique(interactions_old$interactionType)
interaction_types = data.frame(interactionTypeID = 1:length(ints),
                               interactionType = ints)
rm(ints)

# interaction methods
meths = unique(interactions_old$interactionMethod)
interaction_methods = data.frame(interactionMethodID = 1:length(meths),
                                 interactionMethod = meths)
rm(meths)

# foodwebs
foodwebs = foodwebs_old

#### tables containing foreign keys #######

############  species tables
# NOTE: for a similar taxon name, rank can be inform or not resulting into 2  different species IDs

species <- species_old %>% distinct(acceptedTaxonName, taxonRank, taxonomicStatus, 
                                    vernacularName, taxonomicLevel, metabolicType) %>% 
  left_join(metabolic_types, join_by(metabolicType == metabolicType), keep = FALSE)

# when a species has multiple vernacular names, combine them in one cell (emilio's line...)
# NOTE: it could be better to address cases where one of the entry is na (like 'na, red fox' that should be 'red fox')

species_verns <- species |> group_by(acceptedTaxonName) |> 
  mutate(vern = paste(unique(vernacularName), collapse=";")) |> 
  select(acceptedTaxonName, vernacularName, vern) |> 
  unnest(col = vern) %>% 
  select(-vernacularName) %>% distinct()

# put that back into the species table
species <- species %>% select(-vernacularName) %>%
  left_join(species_verns, join_by(acceptedTaxonName)) %>% 
  rename('vernacularName' = 'vern') %>% 
  distinct()
  
# 
# testthat::expect_identical(species %>% distinct(metabolicTypeID, metabolicType) %>% arrange(metabolicTypeID), 
#                            metabolic_types %>% arrange(metabolicTypeID))
# testthat::expect_identical(species$acceptedTaxonName, unique(species$acceptedTaxonName))

# check doublons in taxonomic accepted names
# number_eq_names = table(species$acceptedTaxonName)
# number_eq_names[number_eq_names >1]
# species[species$acceptedTaxonName == 'Tyrophagus',]

# remove met_type info + reorder:
species <- species %>% mutate(speciesID = row_number())%>% 
  select(speciesID, everything(), -metabolicType)



############  communities table

#  NOTE: missing biomass info?

# in the old database, get information to know in which food webs species occur
newone1 <- species_old %>% left_join(interactions_old, by = c('ID' = 'resourceID')) %>% 
  select(ID, acceptedTaxonName, foodwebID)
newone2 <- species_old %>% left_join(interactions_old, by = c('ID' = 'consumerID')) %>% 
  select(ID, acceptedTaxonName, foodwebID)
newone = rbind(newone1, newone2)
rm(newone1, newone2)
maps_sp_fw = newone %>% left_join(foodwebs_old, by = c('foodwebID' = 'ID')) %>% 
  select(ID, foodwebID)
rm(newone)

communities <- species_old %>% 
  select(ID, lowestMass, highestMass, meanMass, shortestLength, longestLength, meanLength,
         acceptedTaxonName, metabolicType, movementType, sizeReference, sizeMethod, lifeStage) %>% 
  left_join(maps_sp_fw, join_by(ID)) %>% rename('ID', 'ID_sp_old') %>%   # retrieve food web ID. No need to original species ID as species definition changed
  left_join(references, by = c('sizeReference' = 'reference')) %>% select(-sizeReference) %>% #size reference
  left_join(movement_types, join_by(movementType)) %>% select(-movementType) %>% 
  left_join(size_methods, join_by(sizeMethod)) %>% select(-sizeMethod) %>% 
  left_join(life_stages, join_by(lifeStage)) %>% select(-lifeStage)%>% 
  left_join(species, join_by(acceptedTaxonName)) %>% select(-acceptedTaxonName) 

# WARNING: last line is failing because one accepted taxon name could have multiple entires in the species table
# for a given taxa, it can happen that taxon rank is informed and NA, duplicating rows. error arises from gebif queries

# NOTE: here referenceID refers to the referenc used for size. maybe rename to sizeReferenceID?

# TODO: still have to add key and check for remove duplicates

############ interaction table

interactions <- interactions_old %>% 
  left_join(interaction_types, join_by(interactionType)) %>% select(-interactionType) %>% 
  left_join(references, by = c('interactionReference' = 'reference')) %>% select(-interactionReference) %>% #size reference
  left_join(interaction_methods, join_by(interactionMethod)) %>% select(-interactionMethod)


head(interactions)

# NOTE: not a big fan of BasisOfRecord
# TODO: the resource and consumers IDs still correspond to the IDs from the older version of the database. needs to be updated. 









a = data.frame(ID = 1:5, letters = c('a', 'b', 'c', 'd', 'e'))
b = data.frame(ID1 = sample(1:5), ID2 = sample(1:5), info = letters[2:6])

result <- a %>%
  left_join(b, by = c("ID" = "ID1")) %>%
  filter(!is.na(info) | ID %in% b$ID2) %>%
  mutate(info = ifelse(!is.na(info), info, b$info[match(ID, b$ID2)])) %>%
  select(ID, info)





  
  