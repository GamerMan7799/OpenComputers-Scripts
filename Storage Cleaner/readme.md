# AE Storage Cleaner

This script will automatically clean out unneeded items from your ME system.

# Minimum Computer Specs

* Level 2 CPU
* Level 3 RAM (you might be able to get away with less RAM, it depends on how large you ME network is)
* Adapter connected to ME controller 
* Adapter connected to Export Bus (need two if you want both storage and voiding ability)
* Level 1 Hard disk 
* Level 1 Database upgrade

# Copying into OpenComputers

Note that since the script exceeds 256 lines of code, by default you will not be able to copy-paste the entire script in one go.
You can copy-paste up to line 256, and go to line 257 hit CTRL-SHIFT-END, and then copy paste the rest of the code. 

# Running the script

You will need to create two configure files as outlined below for the script to function. The names of the config files can be changed in the script if you want to. 

## Items Config 

By default this is called "/etc/aecleaner-items.cfg", but can be changed.

This configure file controls how the script will handle different items within your system. Each line each its own item. Use a space between each of the different columns of information. 

Keep in mind the script will always discard the first line of information.

The columns are:
* Name
** The name of the item, as it appears when you hover over it
* Action
** The action you want to script to take 
*** Cap = Discards the item when it exceeds the limit
*** Store = Stores the item 
*** Discard = always discards the item 
*** Compress = Will use crafting CPUs to compress an item, such as turning ingots into blocks (currently WIP)
* Limit
** The limit of the item, used for cap and compress only, you can set to 0 for store and discard, or leave blank. 
* Label_optional
** Since some mods use multiple items under the same item name, the label is what Minecraft says the name of the item is. It will look for the label within the name of item, do not include any spaces, use "_" if you do not want to use the label for a compressed material. 
* Compress_name
** Minecraft item name of the compressed material
* Compress_label_optional
** Label for the compressed material.

Example:

```
name action limit label_optional compress_name compress_label_optional
minecraft:dirt cap 500
forestry:bee_drone_ge store 0
thermalfoundation:material cap 1000 sulfur
minecraft:rotten_flesh discard 0 
minecraft:cobblestone compress 500 cobblestone extrautils2:compressedcobblestone double
```

## Buses Config 

By default this is called "/etc/aecleaner-buses.cfg", but can be changed.

Keep in mind the script will always discard the first line of information.

This configure file controls what addresses are used for the different items.

Columns of information are:
* Bus 
** Name of the bus, supports controller, void, or store 
* Address 
** The address of the bus that you get with you Shift-right click on the adapter with the Analyzer
* Direction
** Direction that the export bus is facing, this is required for the script. You can leave controller blank, or just use "none" so it doesn't matter for the controller. 

Example

```
bus address direction
controller 3f5b2196-595d-4a06-9290-80d1c2daeb45 none
void caddda8c-7149-4493-bded-cb6c364799b3 down
store 79175b26-e541-4a20-80b2-5e1b86a215cd south
```


