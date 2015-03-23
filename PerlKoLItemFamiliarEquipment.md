**WARNING:**

This module is currently under active development. This means that:

  1. The API is not complete and functionality is being added and changed as it is developed.
  1. The documentation is likely not up to date with the code.

Using any functionality of this module at this time is just silly and at your own risk.

You've been warned!



# Introduction #

This object represents a Familiar Equipment item.

This object is a subclass of [KoL::Item::Equipment](PerlKoLItemEquipment.md). Please see the documentation for more details on the functionality of this object.

## TODO ##

Need to move the equip, unequip, lock, and unlock functionality from KoL::Familiar(s) to here.

## Methods ##
### new(%args) ###
This is the constructor of the object and should only ever be called by [KoL::Item->new()](PerlKoLItem#new(%args).md).

In addition to the hash arguments that [KoL::Item::Equipment->new()](PerlKoLItemEquipment#new(%args).md) uses, this object also supports:

| **Key** | **Required** | **Description** |
|:--------|:-------------|:----------------|
| feid | No | The id from the available equipment select list. |

### subtype() ###
### power() ###
### muscleRequired() ###
### mysticalityRequired() ###
### moxieRequired() ###
### levelRequired() ###
These methods are stubbed out as they serve no purpose for Familiar Equipment.

### setLocked($val) ###
Sets the locked status of the item. This is only intended to be used by the controller's _update()_ method to note if the item is equipped to the current familiar and is in a locked state. It is not advised that bot builders call this method directly.

### locked() ###
Returned 1|0 if the item is currently in a locked state.

As this information is not static (e.g. not from the description) it will call the controlling object's _update()_ method prior to returning a result. See [KoL::Item::Misc->getInfo()](PerlKoLItemMisc#getInfo($key).md) for more details.

**Example:**
```
if ($equip->locked()) {
    # ...
}
```


### feid() ###
Returns the _feid_ value or undef. This only has meaning for the purposes of equipping an item to the current familiar and as such isn't expected to be called by bot builders.