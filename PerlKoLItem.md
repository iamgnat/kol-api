

# Introduction #

This module is not intended for usage by bot builders. It is a helper module to other modules to simplify the creating of a type specific item objects. When the _new()_ method is called, rather than return an object of type _KoL::Item_ it returns the type specific object that it created for you (e.g. _KoL::Item::Booze_).

The object returned is based on the "Type" from the item description. Where there is no type, [KoL::Item::Misc](PerlKoLItemMisc.md) is used. If the type name contains "weapon", [KoL::Item::Weapon](PerlKoLItemWeapon.md) is used and it's sub-type value is set to the full type string. For all other types, spaces and special characters are removed and the first letter of each word is capitalized (e.g. "off-hand item" -> "[OffHandItem](PerlKoLItemOffHandItem.md)").

## Objects ##

  * [KoL::Item::Accessory](PerlKoLItemAccessory.md)
  * [KoL::Item::Booze](PerlKoLItemBooze.md)
  * [KoL::Item::CombatItem](PerlKoLItemCombatItem.md)
  * [KoL::Item::CraftingItem](PerlKoLItemCraftingItem.md)
  * [KoL::Item::Familiar](PerlKoLItemFamiliar.md)
  * [KoL::Item::FamiliarEquipment](PerlKoLItemFamiliarEquipment.md)
  * [KoL::Item::Food](PerlKoLItemFood.md)
  * [KoL::Item::Hat](PerlKoLItemHat.md)
  * [KoL::Item::Misc](PerlKoLItemMisc.md)
  * [KoL::Item::OffHandItem](PerlKoLItemOffHandItem.md)
  * [KoL::Item::Pants](PerlKoLItemPants.md)
  * [KoL::Item::Potion](PerlKoLItemPotion.md)
  * [KoL::Item::Shirt](PerlKoLItemShirt.md)
  * [KoL::Item::Usable](PerlKoLItemUsable.md)
  * [KoL::Item::Weapon](PerlKoLItemWeapon.md)

## Methods ##
### new(%args) ###
This is the pseudo-constructor of the object.

The argument is a hash that can contain the following information:

| **Key** | **Required** | **Description** |
|:--------|:-------------|:----------------|
| controller | Yes | The object that is acting as the controller for the item being created. |
| name | No | The name of the item to create. |
| descid | No | The description id of the item to create. |

The _controller_ object must meet the following criteria:

  * Contains a [KoL::Session](PerlKoLSession.md) reference named _session_.
  * Contains a [KoL::Logging](PerlKoLLogging.md) reference named _log_.
  * Has a method named _update()_ that does not require any arguments.

When called, it is expected that the _update()_ method of _controller_ will perform the proper work to re-fetch the most current information. It is suggested that when updating, the controlling object set the _count_ to zero for all items it controls. A _count_ of 0 should indicate to the bot builder that there are no more of these items left in the controlled area (e.g. inventory, closet, display case, clan stash, or mall store).

Either the _name_ or _descid_ element must be present. If _descid_ is present, it looks up the item information using 'desc\_item.php'. If _descid_ is not present, it queries the KoL Wiki for the _name_ to get the _descid_ and then looks up in the information as described.

See the individual item types for additional elements that are relevant to their specific type.

If there is an error, _undef_ is returned and _$@_ is set. The exception to this rule is if there is no object for the item type at this time. In that case, an error is written using [KoL::Logging->error()](PerlKoLLogging#error($msg).md) telling the user that the item type's object does not exist and it instead will use [KoL::Item::Misc](PerlKoLItemMisc.md) as the object type instead. It also informs them that this is a bug and requests that they report it.

**Example:**

```
my $item = KoL::Item->new('controller' => $self, 'name' => 'bottle of gin');
if (!$item) {
    print "Unable to create item: $@\n";
}
}
```