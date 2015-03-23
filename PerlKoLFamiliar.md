

# Introduction #

This module offers an object oriented view of a familiar. Instances of this object are intended to be created by [KoL::Terrarium->update()](PerlKoLTerrarium#update().md) and as such the functionality to change familiar information will not be documented.

## Methods ##
### id() ###
### type() ###
### name() ###
### weight() ###
### exp() ###
### kills() ###
These methods return the named stat of the familiar.

In the event of an error, _undef_ is returned and _$@_ is set.

**Examples:**

```
my $id = $fam->id();
my $type = $fam->type();
my $name = $fam->name();
my $weight = $fam->weight();
my $exp = $fam->exp();
my $kills = $fam->kills();
```

### equip() ###
This method returns a [KoL::Item::FamiliarEquipment](PerlKoLItemFamiliarEquipment.md) reference to the familiar's equipped item.

If the familiar does not currently have an item equipped or an error occurs, _undef_ is returned. In the event of an error, _$@_ is set to the error message.

**Example:**

```
my $equip = $fam->equip();
if (!$equip && $@) {
    print "Unable to get familiar's equipment: $@\n";
} elsif (!$equip) {
    print "Familiar is not equipped.\n";
} else {
    print "Familiar is equipped.\n";
}
```

### isCurrent() ###
Returns 1|0 if the familiar is the current familiar or not.

If there is an error, 0 is returned and _$@_ is set.

**Example:**

```
my $curr = $fam->isCurrent();
if (!$curr && $@) {
    print "Unable to check if familiar is the current one: $@\n";
} elsif (!$curr) {
    print "Not current.\n";
} else {
    print "Current.\n";
}
```

### unequip() ###
This causes the familiar to be unequipped of it's current item. This is the same as if you called [KoL::Terrarium->unequip()](PerlKoLTerrarium#unequip($fam).md) and passed it this familiar object.

**Example:**
```
if (!$fam->unequip()) {
    print "Unable to unequip familiar: $@\n";
}
```

### changeName($name) ###
This will attempt to change the familiar's name to _$name_. This simply calls [KoL::Terrarium->changeName()](PerlKoLTerrarium#changeName($fam,_$name).md) and passes the familiar object and supplied _$name_.

**Example:**
```
if (!$fam->changeName("Commander Bun Bun")) {
    print "Unable to change familiar name: $@\n";
}
```

### take() ###
Makes this your current familiar. This is a wrapper for [KoL::Terrarium->takeThisOne()](PerlKoLTerrarium#takeThisOne($fam).md) and passes the familiar's object as the variable.

**Example:**
```
if (!$fam->take()) {
    print "Unable to take familiar: $@\n";
}
```
