# TF2 Static Attribute Remover
 Removes static attributes from items

### It kinda sucks ###

It more or less does its job but I've given up on it; decided to release it anyway. 

In TF2, there are different types of attributes (static and dynamic). Dynamic attributes can be messed with with either TF2Items or TF2Attributes. Static attributes, however, are not networked. Therefore it is more difficult to mess with them. The closest thing you have is TF2Items' `PRESERVE_ATTRIBUTES` flag, but that's an all-or-nothing deal. This plugin removes specific static attributes designated by config.

The main caveat with static attributes is that some of the special attribute types have destructors that are called when the attribute is destroyed on an item. There's no all-encompassing method to detect if an attribute takes one of these special types, so the plugin just drops it out of the attribute vector without a whimper. Therefore, this plugin will leak memory if you are removing an attribute that takes a string, dynamic recipe component, world item placement, or item slot criteria.

### Configuration ###

To distinguish between items, you must specify an item's base name as a section name. This falls under `item_name` in items_game.txt. It's the one that looks like `#TF_Weapon_*`. Don't repeat section names or you'll leak memory, idiot.

Next you place the attribute index or indices that you want to remove as a key name, then a 1 or 0 depending on whether or not you actually want it to be removed. It's silly I know but deal with it. The config file should have an example.



Requires [SM-Memory](https://github.com/Scags/SM-Memory). But if you try hard enough, you can break this compatibility requirement.